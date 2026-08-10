import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/analysis_providers.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/analysis/trackable_analysis_screen.dart';

import 'helpers/test_database.dart';

/// Tests for the single-trackable deep-dive screen:
/// - period-vs-previous-period comparison math
/// - the directional % badge (down = taper working)
/// - summary metrics
/// - the underlying provider's previous-period calculation
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  // Fixed "now" so the rolling 7/30-day windows stay deterministic.
  // With this, "last 7 days" = Feb 17..23, and the previous 7 days = Feb 10..16.
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

  Widget buildTestWidget(Trackable trackable) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        nowProvider.overrideWithValue(() => fixedNow),
      ],
      child: MaterialApp(
        home: TrackableAnalysisScreen(trackable: trackable),
      ),
    );
  }

  Future<void> cleanUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
    await tester.pumpAndSettle();
  }

  testWidgets('shows trackable name and default 7-day period', (tester) async {
    final caffeine = (await db.getTrackable(1))!;

    await tester.pumpWidget(buildTestWidget(caffeine));
    await tester.pumpAndSettle();

    expect(find.text('Caffeine'), findsOneWidget);
    // Preset switcher segments.
    expect(find.text('7 days'), findsOneWidget);
    expect(find.text('30 days'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('computes this-vs-previous averages and a downward change badge', (
    tester,
  ) async {
    final caffeine = (await db.getTrackable(1))!;

    // Current window (Feb 17..23, 7 days): one 210 mg dose -> avg 30 mg/day.
    await db.insertDoseLog(1, 210, DateTime(2026, 2, 20, 9));
    // Previous window (Feb 10..16, 7 days): one 420 mg dose -> avg 60 mg/day.
    await db.insertDoseLog(1, 420, DateTime(2026, 2, 13, 9));

    await tester.pumpWidget(buildTestWidget(caffeine));
    await tester.pumpAndSettle();

    // Comparison card: this period 30/day, previous 60/day.
    expect(find.text('30 mg/day'), findsOneWidget);
    expect(find.text('60 mg/day'), findsOneWidget);
    // (30 - 60) / 60 = -50% -> "50% lower vs previous".
    expect(find.text('50% lower vs previous'), findsOneWidget);

    // Summary metrics for the current period. 210 appears twice (total +
    // daily high, since all doses fall on one day), so assert "at least one".
    expect(find.text('210 mg'), findsWidgets); // total / daily high
    expect(find.text('30 mg'), findsOneWidget); // daily average (unique)
    expect(find.text('1'), findsOneWidget); // doses logged

    await cleanUp(tester);
  });

  testWidgets('shows "higher" badge when consumption went up', (tester) async {
    final caffeine = (await db.getTrackable(1))!;

    // Current 80/day (560 total), previous 40/day (280 total) -> +100% higher.
    await db.insertDoseLog(1, 560, DateTime(2026, 2, 20, 9));
    await db.insertDoseLog(1, 280, DateTime(2026, 2, 13, 9));

    await tester.pumpWidget(buildTestWidget(caffeine));
    await tester.pumpAndSettle();

    expect(find.text('100% higher vs previous'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows no-comparison message when previous period is empty', (
    tester,
  ) async {
    final caffeine = (await db.getTrackable(1))!;

    // Only current-period data; nothing in the previous window.
    await db.insertDoseLog(1, 100, DateTime(2026, 2, 20, 9));

    await tester.pumpWidget(buildTestWidget(caffeine));
    await tester.pumpAndSettle();

    expect(
      find.text('No data for the previous period to compare.'),
      findsOneWidget,
    );

    await cleanUp(tester);
  });

  testWidgets('shows empty chart state when the period has no doses', (
    tester,
  ) async {
    final caffeine = (await db.getTrackable(1))!;

    await tester.pumpWidget(buildTestWidget(caffeine));
    await tester.pumpAndSettle();

    expect(find.text('No doses logged in this period.'), findsOneWidget);

    await cleanUp(tester);
  });

  group('trackableAnalysisProvider math', () {
    test('computes previous-period totals and percent change', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          nowProvider.overrideWithValue(() => fixedNow),
        ],
      );
      addTearDown(container.dispose);

      // Current window Feb 17..23: 150 total. Previous Feb 10..16: 300 total.
      await db.insertDoseLog(1, 150, DateTime(2026, 2, 20, 9));
      await db.insertDoseLog(1, 300, DateTime(2026, 2, 13, 9));

      final args = (
        trackableId: 1,
        start: DateTime(2026, 2, 17),
        end: DateTime(2026, 2, 23),
      );

      // Keep the family provider alive while we await it — Riverpod 3
      // auto-disposes providers with no active listener, which would otherwise
      // dispose the stream mid-load. A widget's ref.watch does this normally.
      container.listen(trackableAnalysisProvider(args), (_, _) {});

      // Read the stream's first emitted value.
      final data = await container.read(
        trackableAnalysisProvider(args).future,
      );

      expect(data.periodDays, 7);
      expect(data.total, 150);
      expect(data.averagePerDay, closeTo(150 / 7, 0.001));
      expect(data.previousTotal, 300);
      expect(data.previousAveragePerDay, closeTo(300 / 7, 0.001));
      expect(data.doseCount, 1);
      expect(data.previousDoseCount, 1);
      // (150 - 300) / 300 = -50%.
      expect(data.averageChangePercent, closeTo(-50, 0.001));
      expect(data.dailyTotals.length, 7);
      // Feb 20 is index 3 in a window starting Feb 17.
      expect(data.dailyTotals[3].total, 150);
    });
  });
}
