import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/dashboard_screen.dart';
import 'package:taper/screens/dashboard/widgets/substance_card.dart';

import 'helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
  });

  tearDown(() async {
    try {
      await db.close();
    } catch (_) {}
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
    );
  }

  Future<void> pumpAndWait(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> pumpAndWaitLong(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> cleanUp(WidgetTester tester, {bool hasNavigated = false}) async {
    if (hasNavigated) {
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await db.close();
    await tester.pump();
  }

  testWidgets('shows Dashboard header', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    expect(find.text('Dashboard'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows cards for visible substances', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    expect(find.byType(SubstanceCard), findsNWidgets(2));
    expect(find.text('Caffeine'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Alcohol'), findsNothing);

    await cleanUp(tester);
  });

  testWidgets('empty state when no visible substances', (tester) async {
    await db.toggleSubstanceVisibility(1, false);
    await db.toggleSubstanceVisibility(2, false);

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.textContaining('No visible substances'), findsOneWidget);
    expect(find.byType(SubstanceCard), findsNothing);

    await cleanUp(tester);
  });

  testWidgets('card shows substance name and stats with /', (tester) async {
    await db.insertDoseLog(1, 90, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    expect(find.text('Caffeine'), findsOneWidget);
    // Compact format: "active / total unit" — should contain "/".
    expect(find.textContaining('/'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('card shows just total for substance without half-life', (tester) async {
    await db.insertDoseLog(2, 500, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    // Water card: "500 ml" (no "active" stat).
    expect(find.text('500 ml'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('card hides Repeat Last when no doses exist', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    expect(find.text('Repeat Last'), findsNothing);

    await cleanUp(tester);
  });

  testWidgets('card shows Repeat Last when doses exist', (tester) async {
    await db.insertDoseLog(1, 90, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    expect(find.text('Repeat Last'), findsWidgets);

    await cleanUp(tester);
  });

  testWidgets('Repeat Last inserts dose and shows SnackBar', (tester) async {
    await db.insertDoseLog(1, 95, DateTime.now().subtract(const Duration(hours: 1)));

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    await tester.tap(find.text('Repeat Last').first);
    await tester.pump();
    await pumpAndWaitLong(tester);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Logged 95'), findsOneWidget);

    final logs = await db.select(db.doseLogs).get();
    expect(logs.length, 2);
    expect(logs.last.amount, 95.0);

    await cleanUp(tester);
  });

  testWidgets('Add Dose opens quick-add dialog', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    // Tap "Add Dose" on any card.
    await tester.tap(find.text('Add Dose').first);
    await tester.pump();

    // Should show the quick-add dialog (not navigate to LogDoseScreen).
    // Dialog title: "Log Caffeine" (first card = Caffeine).
    expect(find.text('Log Caffeine'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);

    // Dismiss dialog.
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    await cleanUp(tester);
  });

  testWidgets('View Log navigates to SubstanceLogScreen', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    await tester.tap(find.text('View Log').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Caffeine'), findsWidgets);

    await cleanUp(tester, hasNavigated: true);
  });

}
