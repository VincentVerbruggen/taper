import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/dashboard/widgets/daily_max_concentration_card.dart';

import 'helpers/test_database.dart';

/// Widget tests for DailyMaxConcentrationCard — the decay-aware sibling of the
/// daily totals card. It plots the highest active concentration reached each
/// day over the past 30 days.
///
/// Tests that the card:
/// - Renders with trackable name + "Daily Max" label
/// - Shows the empty state when no doses exist
/// - Renders the chart + "avg peak" subtitle when doses exist
/// - Shows a "no decay model" hint for non-decaying trackables (Water)
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
        // Freeze time so the 30-day chart window stays deterministic.
        nowProvider.overrideWithValue(() => fixedNow),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DailyMaxConcentrationCard(trackableId: trackableId),
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

  testWidgets('renders with trackable name and Daily Max label', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    expect(find.textContaining('Caffeine'), findsOneWidget);
    expect(find.textContaining('Daily Max'), findsOneWidget);
    expect(find.text('30 days'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows empty state when no doses in range', (tester) async {
    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    expect(find.textContaining('No doses in the last 30 days'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);

    await cleanUp(tester);
  });

  testWidgets('shows chart and avg peak when doses exist', (tester) async {
    final now = fixedNow;
    await db.insertDoseLog(1, 90, now.subtract(const Duration(days: 1)));
    await db.insertDoseLog(1, 180, now.subtract(const Duration(days: 2)));
    await db.insertDoseLog(1, 90, now);

    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    expect(find.byType(LineChart), findsOneWidget);
    // Subtitle should describe the peak statistics.
    expect(find.textContaining('avg peak:'), findsOneWidget);
    expect(find.textContaining('highest:'), findsOneWidget);

    // Single peak series, no overlay.
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData, hasLength(1));

    await cleanUp(tester);
  });

  testWidgets('shows hint for trackable without a decay model (Water)', (
    tester,
  ) async {
    // Water is trackable ID 2 from the seeder — decay model "none".
    await db.insertDoseLog(2, 500, fixedNow);

    await tester.pumpWidget(buildTestWidget(trackableId: 2));
    await pumpAndWaitLong(tester);

    expect(find.textContaining('Water'), findsOneWidget);
    expect(find.textContaining('No decay model'), findsOneWidget);
    // No chart for a non-decaying trackable.
    expect(find.byType(LineChart), findsNothing);

    await cleanUp(tester);
  });
}
