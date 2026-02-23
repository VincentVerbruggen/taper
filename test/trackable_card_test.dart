import 'dart:convert';

import 'package:drift/drift.dart';
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
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
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

  testWidgets('shows mode toggle icon in decay mode by default', (tester) async {
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

    await tester.pumpWidget(buildTestWidget(
      trackableId: 1,
      config: jsonEncode({'mode': 'total'}),
    ));
    await pumpAndWaitLong(tester);

    // Total mode → bar_chart icon visible.
    expect(find.byIcon(Icons.bar_chart), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('total mode shows "today" in stats text', (tester) async {
    await db.insertDoseLog(1, 90, DateTime.now());

    await tester.pumpWidget(buildTestWidget(
      trackableId: 1,
      config: jsonEncode({'mode': 'total'}),
    ));
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

    await tester.pumpWidget(buildTestWidget(
      trackableId: 1,
      widgetId: widgetId,
    ));
    await pumpAndWaitLong(tester);

    // Tap the mode toggle (show_chart icon → should switch to total).
    await tester.tap(find.byIcon(Icons.show_chart));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify the config was persisted to the DB.
    final updated = await (db.select(db.dashboardWidgets)
          ..where((t) => t.id.equals(widgetId)))
        .getSingle();
    final configMap = jsonDecode(updated.config) as Map<String, dynamic>;
    expect(configMap['mode'], 'total');

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
