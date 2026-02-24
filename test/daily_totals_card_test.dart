import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/dashboard/widgets/daily_totals_card.dart';

import 'helpers/test_database.dart';

/// Widget tests for DailyTotalsCard — the 30-day daily totals dashboard card.
///
/// Tests that the card:
/// - Renders with trackable name + "Daily Totals" label
/// - Shows average in subtitle when doses exist
/// - Shows empty state when no doses in range
/// - Chart renders (find LineChart widget)
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  final fixedNow = DateTime(2026, 2, 23, 12);

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

  Widget buildTestWidget({int trackableId = 1}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Freeze time so chart windows and taper-target sampling stay stable.
        nowProvider.overrideWithValue(() => fixedNow),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DailyTotalsCard(trackableId: trackableId),
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
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await db.close();
    await tester.pump();
  }

  testWidgets('renders with trackable name and Daily Totals label', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    // Title should contain trackable name and "Daily Totals".
    expect(find.textContaining('Caffeine'), findsOneWidget);
    expect(find.textContaining('Daily Totals'), findsOneWidget);
    // "30 days" label should be visible.
    expect(find.text('30 days'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows empty state when no doses in range', (tester) async {
    // Don't insert any doses — the card should show an empty state.
    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    expect(find.textContaining('No doses in the last 30 days'), findsOneWidget);
    // No chart should render when there are no doses.
    expect(find.byType(LineChart), findsNothing);

    await cleanUp(tester);
  });

  testWidgets('shows chart and average when doses exist', (tester) async {
    // Insert doses on different days within the last 30 days.
    final now = fixedNow;
    await db.insertDoseLog(1, 90, now.subtract(const Duration(days: 1)));
    await db.insertDoseLog(1, 180, now.subtract(const Duration(days: 2)));
    await db.insertDoseLog(1, 90, now);

    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    // Chart should render.
    expect(find.byType(LineChart), findsOneWidget);
    // Subtitle should show the average.
    expect(find.textContaining('avg:'), findsOneWidget);
    expect(find.textContaining('/day'), findsOneWidget);

    // Without an active plan, the chart should render only the totals line.
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData, hasLength(1));

    await cleanUp(tester);
  });

  testWidgets('renders for Water trackable (no half-life)', (tester) async {
    // Water is trackable ID 2 from the seeder (no decay model).
    // Daily totals should still work — it just sums amounts per day.
    await db.insertDoseLog(2, 500, fixedNow);

    await tester.pumpWidget(buildTestWidget(trackableId: 2));
    await pumpAndWaitLong(tester);

    expect(find.textContaining('Water'), findsOneWidget);
    expect(find.textContaining('Daily Totals'), findsOneWidget);
    // Chart should render.
    expect(find.byType(LineChart), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('draws dashed taper target line when active plan exists', (
    tester,
  ) async {
    // Add at least one dose so the totals chart renders (non-empty state).
    await db.insertDoseLog(1, 120, fixedNow);
    // Active plan spanning the fixed "now" window.
    await db.insertTaperPlan(
      1,
      400,
      100,
      DateTime(2026, 2, 1, 5),
      DateTime(2026, 3, 15, 5),
    );

    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    // Totals line + taper target overlay.
    expect(chart.data.lineBarsData, hasLength(2));

    final taperLine = chart.data.lineBarsData.first;
    expect(taperLine.dashArray, isNotNull);
    expect(taperLine.dashArray, containsAllInOrder([6, 4]));
    expect(taperLine.isCurved, isFalse);

    await cleanUp(tester);
  });
}
