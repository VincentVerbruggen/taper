import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/dashboard/taper_progress_screen.dart';

import 'helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    // SharedPreferences mock — needed because TaperProgressScreen reads
    // dayBoundaryHourProvider, which depends on sharedPreferencesProvider.
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = createTestDatabase();
  });

  tearDown(() async {
    try {
      await db.close();
    } catch (_) {}
  });

  /// Build a test widget wrapping TaperProgressScreen.
  Widget buildTestWidget(Trackable trackable, TaperPlan plan) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        home: TaperProgressScreen(trackable: trackable, taperPlan: plan),
      ),
    );
  }

  Future<void> pumpAndWait(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> cleanUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await db.close();
    await tester.pump();
  }

  Future<Trackable> getCaffeine() async {
    final trackables = await db.select(db.trackables).get();
    return trackables.firstWhere((s) => s.name == 'Caffeine');
  }

  /// Helper to create a TaperPlan object for testing.
  /// Uses the real DB to insert and retrieve so we get a fully valid object.
  Future<TaperPlan> createTestPlan(int trackableId) async {
    final id = await db.insertTaperPlan(
      trackableId,
      400,
      100,
      DateTime(2026, 2, 1, 5),
      DateTime(2026, 3, 1, 5),
    );
    return (await db.select(db.taperPlans).get())
        .firstWhere((p) => p.id == id);
  }

  // --- Basic rendering tests ---

  testWidgets('shows Taper Progress title', (tester) async {
    final caffeine = await getCaffeine();
    final plan = await createTestPlan(caffeine.id);
    await tester.pumpWidget(buildTestWidget(caffeine, plan));
    await pumpAndWait(tester);

    expect(find.text('Taper Progress'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows plan summary text', (tester) async {
    final caffeine = await getCaffeine();
    final plan = await createTestPlan(caffeine.id);
    await tester.pumpWidget(buildTestWidget(caffeine, plan));
    await pumpAndWait(tester);

    // Should show the amount range and date range.
    // "400 → 100 mg · Feb 1 – Mar 1"
    expect(find.textContaining('400'), findsWidgets);
    expect(find.textContaining('100'), findsWidgets);

    await cleanUp(tester);
  });

  testWidgets('shows Active status chip', (tester) async {
    final caffeine = await getCaffeine();
    final plan = await createTestPlan(caffeine.id);
    await tester.pumpWidget(buildTestWidget(caffeine, plan));
    await pumpAndWait(tester);

    expect(find.text('Active'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('renders chart widget', (tester) async {
    final caffeine = await getCaffeine();
    final plan = await createTestPlan(caffeine.id);
    await tester.pumpWidget(buildTestWidget(caffeine, plan));
    await pumpAndWait(tester);

    // The chart should be rendered.
    expect(find.byType(LineChart), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows stats text with Day X of Y', (tester) async {
    final caffeine = await getCaffeine();
    final plan = await createTestPlan(caffeine.id);
    await tester.pumpWidget(buildTestWidget(caffeine, plan));
    await pumpAndWait(tester);

    // Should show "Day X of 28" somewhere (the exact day depends on when the test runs).
    expect(find.textContaining('Day'), findsWidgets);
    expect(find.textContaining('of'), findsWidgets);

    await cleanUp(tester);
  });

  testWidgets('handles no doses (target line only)', (tester) async {
    final caffeine = await getCaffeine();
    final plan = await createTestPlan(caffeine.id);
    // Don't insert any doses — should still render without errors.
    await tester.pumpWidget(buildTestWidget(caffeine, plan));
    await pumpAndWait(tester);

    // Chart should still render with just the target line.
    expect(find.byType(LineChart), findsOneWidget);
    // No crash, no error text.
    expect(find.textContaining('Error'), findsNothing);

    await cleanUp(tester);
  });
}
