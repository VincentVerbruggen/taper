import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/dashboard/substance_log_screen.dart';
import 'package:taper/screens/log/edit_dose_screen.dart';

import 'helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late Substance caffeine;

  setUp(() async {
    db = createTestDatabase();
    final substances = await db.select(db.substances).get();
    caffeine = substances.firstWhere((s) => s.name == 'Caffeine');
  });

  tearDown(() async {
    try {
      await db.close();
    } catch (_) {}
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: SubstanceLogScreen(substance: caffeine),
      ),
    );
  }

  Future<void> pumpAndWait(WidgetTester tester) async {
    await tester.pump();
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

  testWidgets('shows substance name in AppBar', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.text('Caffeine'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows empty state when no doses', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.text('No doses logged yet.'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows doses grouped by day', (tester) async {
    final now = DateTime.now();
    await db.insertDoseLog(caffeine.id, 90, now);
    await db.insertDoseLog(caffeine.id, 90, now.subtract(const Duration(hours: 1)));

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('90 mg'), findsNWidgets(2));

    await cleanUp(tester);
  });

  testWidgets('daily total shown in header', (tester) async {
    final now = DateTime.now();
    await db.insertDoseLog(caffeine.id, 90, now);
    await db.insertDoseLog(caffeine.id, 60, now.subtract(const Duration(hours: 1)));

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.text('150 mg'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('delete removes dose from list', (tester) async {
    await db.insertDoseLog(caffeine.id, 100, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.text('100 mg'), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await pumpAndWait(tester);

    expect(find.text('100 mg'), findsNothing);
    expect(find.text('No doses logged yet.'), findsOneWidget);

    final logs = await db.select(db.doseLogs).get();
    expect(logs, isEmpty);

    await cleanUp(tester);
  });

  testWidgets('tap navigates to edit screen', (tester) async {
    await db.insertDoseLog(caffeine.id, 75, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    await tester.tap(
      find.ancestor(
        of: find.text('75 mg'),
        matching: find.byType(ListTile),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(EditDoseScreen), findsOneWidget);
    expect(find.text('Edit Dose'), findsOneWidget);

    await cleanUp(tester, hasNavigated: true);
  });

  // --- FAB + quick-add dialog tests ---

  testWidgets('FAB opens quick-add dialog', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(find.text('Log Caffeine'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Log'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();

    await cleanUp(tester);
  });

  testWidgets('quick-add dialog logs dose and closes', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '200');
    await tester.pump();

    await tester.tap(find.text('Log'));
    await tester.pump();
    await pumpAndWait(tester);

    // Dialog should be dismissed.
    expect(find.text('Log Caffeine'), findsNothing);

    // SnackBar should confirm the dose.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Logged 200'), findsOneWidget);

    // Verify dose was inserted.
    final logs = await db.select(db.doseLogs).get();
    expect(logs.length, 1);
    expect(logs.first.amount, 200.0);
    expect(logs.first.substanceId, caffeine.id);

    await cleanUp(tester);
  });
}
