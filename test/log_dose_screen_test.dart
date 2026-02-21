import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/log/edit_dose_screen.dart';
import 'package:taper/screens/log/log_dose_screen.dart';

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
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: const MaterialApp(
        home: LogDoseScreen(),
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

  // --- Main screen tests ---

  testWidgets('shows Log header', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.text('Log'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows empty state when no doses logged', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.textContaining('No doses logged yet'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows FAB for adding doses', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await cleanUp(tester);
  });

  // --- Recent logs list tests ---

  testWidgets('recent log entry shows substance unit', (tester) async {
    // Insert a Water dose (id=2, unit="ml") directly in the DB.
    await db.insertDoseLog(2, 500, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // The log tile should show "Water — 500 ml" (not "500 mg").
    expect(find.text('Water — 500 ml'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('log entries are wrapped in Card.outlined', (tester) async {
    await db.insertDoseLog(1, 150, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(
      find.ancestor(
        of: find.text('Caffeine — 150 mg'),
        matching: find.byType(Card),
      ),
      findsOneWidget,
    );

    await cleanUp(tester);
  });

  testWidgets('tapping a log entry navigates to EditDoseScreen', (tester) async {
    await db.insertDoseLog(1, 120, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    await tester.tap(find.text('Caffeine — 120 mg'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(EditDoseScreen), findsOneWidget);
    expect(find.text('Edit Dose'), findsOneWidget);

    await cleanUp(tester, hasNavigated: true);
  });

  testWidgets('delete removes dose from list and database', (tester) async {
    await db.insertDoseLog(1, 200, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.text('Caffeine — 200 mg'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await pumpAndWait(tester);

    expect(find.text('Caffeine — 200 mg'), findsNothing);
    expect(find.textContaining('No doses logged yet'), findsOneWidget);

    final logs = await db.select(db.doseLogs).get();
    expect(logs, isEmpty);

    await cleanUp(tester);
  });

  // --- Bottom sheet log form tests ---

  testWidgets('FAB opens log dose bottom sheet', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Tap the FAB to open the bottom sheet.
    await tester.tap(find.byType(FloatingActionButton));
    // Bottom sheet has a slide-up animation (~250ms) AND the inner widget
    // watches visibleSubstancesProvider (async), so we need multiple pump
    // cycles: first for the animation, then for the provider to deliver data.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await pumpAndWait(tester);
    await pumpAndWait(tester);

    // "Log Dose" appears as the heading AND as the FilledButton label.
    expect(find.text('Log Dose'), findsNWidgets(2));
    // And the substance dropdown + amount field.
    expect(find.text('Substance'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);

    // Close the bottom sheet by tapping the heading area.
    await tester.tap(find.text('Log Dose').first);
    await tester.pump(const Duration(milliseconds: 500));

    await cleanUp(tester);
  });

  testWidgets('save works with auto-selected main substance', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Open the bottom sheet.
    await tester.tap(find.byType(FloatingActionButton));
    // Extra pump time for animation + async provider loading.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await pumpAndWait(tester);
    await pumpAndWait(tester);

    // Caffeine is auto-selected. Enter amount and save.
    await tester.enterText(find.byType(TextField).first, '100');
    await tester.pump();

    // Scroll the save button into view (may be off-screen in 600px viewport).
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await pumpAndWait(tester);

    // Verify the dose was saved.
    final logs = await db.select(db.doseLogs).get();
    expect(logs.length, 1);
    expect(logs.first.substanceId, 1);
    expect(logs.first.amount, 100.0);

    await cleanUp(tester);
  });
}
