import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/analysis/analysis_screen.dart';

import 'helpers/test_database.dart';

/// Widget tests for the Analysis tab:
/// - default date range rendering
/// - high/low/avg metric calculations
/// - empty-state messaging
/// - hidden trackable inclusion when it has data
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  // Fixed "now" so the default last-7-days range stays deterministic.
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

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Freeze time so "last 7 days" and picker limits are stable in tests.
        nowProvider.overrideWithValue(() => fixedNow),
      ],
      child: const MaterialApp(home: AnalysisScreen()),
    );
  }

  Future<void> cleanUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await db.close();
    await tester.pumpAndSettle();
  }

  testWidgets('shows Analysis header and default 7-day range', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Analysis'), findsOneWidget);
    expect(find.text('Feb 17 - Feb 23'), findsOneWidget);
    expect(find.text('7 day range'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('computes high/low/average metrics for selected range', (
    tester,
  ) async {
    // Default range with fixedNow (2026-02-23) is Feb 17..23 inclusive.
    // Caffeine doses:
    // - Feb 20: 100 + 50 = 150 day total
    // - Feb 22: 200 day total
    // Totals:
    // - total = 350
    // - daily high = 200
    // - daily low = 0 (days without doses count in range stats)
    // - daily avg = 350 / 7 = 50
    // - dose avg = 350 / 3 = 116.7
    // - dose range = 50..200
    await db.insertDoseLog(1, 100, DateTime(2026, 2, 20, 9));
    await db.insertDoseLog(1, 50, DateTime(2026, 2, 20, 14));
    await db.insertDoseLog(1, 200, DateTime(2026, 2, 22, 10));

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Caffeine'), findsOneWidget);
    expect(find.text('350 mg'), findsOneWidget);
    expect(find.text('200 mg'), findsOneWidget);
    expect(find.text('0 mg'), findsOneWidget);
    expect(find.text('50 mg'), findsOneWidget);
    expect(find.text('116.7 mg'), findsOneWidget);
    expect(find.text('50 - 200 mg'), findsOneWidget);
    expect(find.text('Peak active concentration'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('computes peak active concentration for decay trackables', (
    tester,
  ) async {
    // Two equal doses one hour apart (Caffeine, exponential + 45m absorption).
    // At 10:45:
    // - First dose has decayed for 1 hour after absorption -> 100 * 0.5^(1/5)
    // - Second dose just finished absorption -> 100
    // Peak active is ~187.1 mg at this sample point.
    await db.insertDoseLog(1, 100, DateTime(2026, 2, 20, 9));
    await db.insertDoseLog(1, 100, DateTime(2026, 2, 20, 10));

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Peak active concentration'), findsOneWidget);
    expect(find.text('187.1 mg'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows empty-state message when range has no doses', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('0 doses logged'), findsOneWidget);
    // Visible trackables (Caffeine + Water) each show an empty-state line.
    expect(find.text('No doses logged in this range.'), findsNWidgets(2));

    await cleanUp(tester);
  });

  testWidgets('includes hidden trackable when it has doses in range', (
    tester,
  ) async {
    // Alcohol is seeded as hidden, but analysis should still include it
    // if there is data in the selected range.
    await db.insertDoseLog(3, 18, DateTime(2026, 2, 22, 20));

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Alcohol'), findsOneWidget);
    // The same number can appear in multiple metric cells (total/high/range),
    // so we assert "at least one" instead of exactly one.
    expect(find.text('18 ml'), findsWidgets);

    await cleanUp(tester);
  });

  testWidgets('shows N/A concentration for no-decay trackables', (
    tester,
  ) async {
    // Water (trackable 2) uses decayModel=none.
    await db.insertDoseLog(2, 500, DateTime(2026, 2, 21, 12));

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Peak active concentration'), findsOneWidget);
    expect(find.text('N/A (no decay model)'), findsOneWidget);

    await cleanUp(tester);
  });
}
