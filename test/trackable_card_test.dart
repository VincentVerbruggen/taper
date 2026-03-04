import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/dashboard/widgets/trackable_card.dart';

import 'helpers/test_database.dart';

/// Widget tests for TrackableCard — the unified decay card with enhanced visuals
/// and dual-mode chart (decay focus / total focus).
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = createTestDatabase();
  });

  tearDown(() async {
    try {
      await db.close();
    } catch (_) {}
  });

  Widget buildTestWidget({
    int trackableId = 1,
    int? widgetId,
    String config = '{}',
    DateTime? now,
  }) {
    final overrides = [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ];
    if (now != null) {
      overrides.add(nowProvider.overrideWithValue(() => now));
    }

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrackableCard(
              trackableId: trackableId,
              widgetId: widgetId,
              config: config,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpAndWaitLong(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> cleanUp(WidgetTester tester) async {
    // Dispose widget tree FIRST, then close DB — prevents Drift deadlock.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await db.close();
    await tester.pump();
  }

  // --- Basic rendering tests ---

  testWidgets('renders with trackable name and stats', (tester) async {
    await db.insertDoseLog(1, 90, DateTime.now());

    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    expect(find.text('Caffeine'), findsOneWidget);
    // Decay mode (default): stats show "active / total unit" format with "/".
    expect(find.textContaining('/'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('chart renders with LineChart widget', (tester) async {
    await db.insertDoseLog(1, 90, DateTime.now());

    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    expect(find.byType(LineChart), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('chart disables grid and uses totals-style y-axis labels', (
    tester,
  ) async {
    await db.insertDoseLog(1, 90, DateTime.now());

    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.gridData.show, isFalse);
    expect(chart.data.borderData.show, isFalse);
    expect(chart.data.titlesData.bottomTitles.sideTitles.showTitles, isTrue);
    // Keep left Y labels visible so Decay matches Daily Totals axis style.
    expect(chart.data.titlesData.leftTitles.sideTitles.showTitles, isTrue);
    expect(chart.data.titlesData.topTitles.sideTitles.showTitles, isFalse);
    expect(chart.data.titlesData.rightTitles.sideTitles.showTitles, isFalse);

    await cleanUp(tester);
  });

  testWidgets('decay mode draws active_amount thresholds as horizontal lines', (
    tester,
  ) async {
    await db.insertDoseLog(1, 90, DateTime.now());
    await db.insertThreshold(
      1,
      'Active cap',
      120,
      comparisonType: 'active_amount',
    );

    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(
      chart.data.extraLinesData.horizontalLines.any((line) => line.y == 120),
      isTrue,
    );

    await cleanUp(tester);
  });

  testWidgets('decay mode draws target markers on the chart', (tester) async {
    await db.insertDoseLog(1, 90, DateTime.now());
    await db.insertTarget(
      trackableId: 1,
      name: 'Bedtime',
      amount: 80,
      time: '22:00',
    );

    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final targetBars = chart.data.lineBarsData.where(
      (bar) => bar.barWidth == 0 && bar.dotData.show,
    );
    expect(targetBars, isNotEmpty);
    expect(targetBars.first.spots.any((spot) => spot.y == 80), isTrue);

    await cleanUp(tester);
  });

  testWidgets('bottom hour labels are clock-aligned to 6-hour anchors', (
    tester,
  ) async {
    // One dose is enough to render the chart and expose axis title callbacks.
    await db.insertDoseLog(1, 90, DateTime.now());

    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final sideTitles = chart.data.titlesData.bottomTitles.sideTitles;

    // Interval is hourly, then labels are filtered to real clock anchors.
    // This avoids shifted labels like 05/11/17 when day boundary is 05:00.
    expect(sideTitles.interval, 1);

    TitleMeta buildMeta(double value) {
      return TitleMeta(
        min: chart.data.minX,
        max: chart.data.maxX,
        parentAxisSize: 300,
        axisPosition: value,
        appliedInterval: sideTitles.interval ?? 1,
        sideTitles: sideTitles,
        formattedValue: value.toString(),
        axisSide: AxisSide.bottom,
      );
    }

    // With default 05:00 day boundary and extended start at -6h,
    // x = -5h maps to 00:00 (should be shown), while x = 0h maps to 05:00
    // (should be hidden because it's not a 6-hour clock anchor).
    final midnightLabel = sideTitles.getTitlesWidget(-5, buildMeta(-5));
    final fiveAmLabel = sideTitles.getTitlesWidget(0, buildMeta(0));

    expect(midnightLabel, isA<Text>());
    expect((midnightLabel as Text).data, '00:00');
    expect(fiveAmLabel, isA<SizedBox>());

    await cleanUp(tester);
  });

  testWidgets('shows Repeat Last button when doses exist', (tester) async {
    await db.insertDoseLog(1, 90, DateTime.now());

    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    expect(find.text('Repeat Last'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('hides Repeat Last when no doses exist', (tester) async {
    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    expect(find.text('Repeat Last'), findsNothing);
    expect(find.text('Add Dose'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows Add Dose and View Log buttons', (tester) async {
    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    expect(find.text('Add Dose'), findsOneWidget);
    expect(find.text('View Log'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows overflow menu icon', (tester) async {
    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    expect(find.byIcon(Icons.more_vert), findsOneWidget);

    await cleanUp(tester);
  });

  // --- Dual-mode chart tests ---

  testWidgets('shows mode toggle icon in decay mode by default', (
    tester,
  ) async {
    // Need a dose so the chart and toggle are rendered.
    await db.insertDoseLog(1, 90, DateTime.now());

    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    // Default mode is decay → show_chart icon visible.
    expect(find.byIcon(Icons.show_chart), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows bar_chart icon when config mode is total', (tester) async {
    await db.insertDoseLog(1, 90, DateTime.now());

    await tester.pumpWidget(
      buildTestWidget(trackableId: 1, config: jsonEncode({'mode': 'total'})),
    );
    await pumpAndWaitLong(tester);

    // Total mode → bar_chart icon visible.
    expect(find.byIcon(Icons.bar_chart), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('total mode shows "today" in stats text', (tester) async {
    await db.insertDoseLog(1, 90, DateTime.now());

    await tester.pumpWidget(
      buildTestWidget(trackableId: 1, config: jsonEncode({'mode': 'total'})),
    );
    await pumpAndWaitLong(tester);

    // Total mode stats: "X mg today" format.
    expect(find.textContaining('today'), findsOneWidget);
    // Should NOT show the "active / total" format.
    expect(find.textContaining('/'), findsNothing);

    await cleanUp(tester);
  });

  testWidgets('mode toggle persists config to DB', (tester) async {
    await db.insertDoseLog(1, 90, DateTime.now());

    // Get the first dashboard widget ID (seeded by DB).
    final widgets = await db.select(db.dashboardWidgets).get();
    final widgetId = widgets.first.id;

    await tester.pumpWidget(
      buildTestWidget(trackableId: 1, widgetId: widgetId),
    );
    await pumpAndWaitLong(tester);

    // Tap the mode toggle (show_chart icon → should switch to total).
    await tester.tap(find.byIcon(Icons.show_chart));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify the config was persisted to the DB.
    final updated = await (db.select(
      db.dashboardWidgets,
    )..where((t) => t.id.equals(widgetId))).getSingle();
    final configMap = jsonDecode(updated.config) as Map<String, dynamic>;
    expect(configMap['mode'], 'total');

    await cleanUp(tester);
  });

  testWidgets('planned doses add projected dashed line and stats label', (
    tester,
  ) async {
    final now = DateTime(2026, 2, 23, 12);
    await db.insertDoseLog(1, 90, now.subtract(const Duration(hours: 2)));
    await db.insertDoseLog(
      1,
      60,
      now.add(const Duration(hours: 1)),
      isPlanned: true,
    );

    await tester.pumpWidget(buildTestWidget(trackableId: 1, now: now));
    await pumpAndWaitLong(tester);

    // Stats should communicate there is planned intake.
    expect(find.textContaining('planned'), findsOneWidget);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final hasProjectedDash = chart.data.lineBarsData.any(
      (bar) =>
          bar.dashArray != null &&
          bar.dashArray!.length == 2 &&
          bar.dashArray!.first == 8,
    );
    expect(hasProjectedDash, isTrue);

    await cleanUp(tester);
  });

  testWidgets('no mode toggle for trackable without decay', (tester) async {
    // Water (id=2) has no half-life → no decay → no toggle.
    await db.insertDoseLog(2, 500, DateTime.now());

    await tester.pumpWidget(buildTestWidget(trackableId: 2));
    await pumpAndWaitLong(tester);

    // Neither mode icon should appear.
    expect(find.byIcon(Icons.show_chart), findsNothing);
    expect(find.byIcon(Icons.bar_chart), findsNothing);

    await cleanUp(tester);
  });
}
