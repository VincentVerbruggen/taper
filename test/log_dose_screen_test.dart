import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/log/edit_dose_screen.dart';
import 'package:taper/screens/log/log_dose_screen.dart';

import 'helpers/test_database.dart';

void main() {
  // Each test gets its own in-memory DB — like Laravel's RefreshDatabase.
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    // No need to seed — the database's onCreate migration already inserts
    // substances (Caffeine as main, Water, Alcohol as hidden).
  });

  // Safety net: if a test fails before reaching cleanUp(), the DB still closes.
  // try/catch because closing an already-closed DB throws.
  // Like Laravel's afterEach(() => DB::disconnect()).
  tearDown(() async {
    try {
      await db.close();
    } catch (_) {}
  });

  /// Helper to pump the LogDoseScreen with the test DB injected.
  ///
  /// ProviderScope.overrides replaces the real databaseProvider with our
  /// test DB — like Laravel's $this->mock() or binding a fake in the container.
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

  /// Pump the widget tree and wait for stream providers to emit.
  ///
  /// We use bounded pumps instead of pumpAndSettle() because active Drift
  /// stream providers (visibleSubstancesProvider, doseLogsProvider) can keep
  /// scheduling microtasks/frames that prevent pumpAndSettle from ever
  /// settling. Bounded pumps process a known amount of time and stop.
  /// Like using setTimeout() instead of "wait until idle" in JS tests.
  Future<void> pumpAndWait(WidgetTester tester) async {
    // First pump processes the initial build (shows loading spinners).
    await tester.pump();
    // Second pump with duration lets stream providers emit their data
    // and the widget tree to rebuild with the actual content.
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Dispose the widget tree cleanly after each test.
  ///
  /// CRITICAL ORDERING: Dispose the widget tree (cancels stream subscriptions)
  /// BEFORE closing the DB. If you close the DB first, Drift tries to shut
  /// down while streams still have active listeners → deadlock. Same concept
  /// as unsubscribing from events before destroying the event source.
  /// Like: $component->unmount() first, then DB::disconnect().
  ///
  /// For tests that Navigator.push to a second screen (like EditDoseScreen),
  /// we MUST pop back first. If we try to replace the widget tree while two
  /// routes are stacked, the disposal of dual stream-subscribed screens
  /// causes an infinite rebuild loop. Think of it like closing a modal
  /// before leaving the page.
  Future<void> cleanUp(WidgetTester tester, {bool hasNavigated = false}) async {
    // If we pushed a route, pop it first to get back to a single-screen state.
    if (hasNavigated) {
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    // 1) Dispose ProviderScope + widgets FIRST — this cancels Drift stream
    //    subscriptions so nothing is listening when we close the DB.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    // Let zero-delay timers fire (Drift's stream cleanup schedules these).
    await tester.pump(const Duration(milliseconds: 100));

    // 2) Now close the DB — safe because no streams are listening anymore.
    await db.close();

    // One extra pump to flush any post-close microtasks.
    await tester.pump();
  }

  testWidgets('shows substance dropdown with seeded data', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // The dropdown should show "Caffeine" as an option (auto-selected as main).
    expect(find.text('Substance'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('can log a dose', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Caffeine is auto-selected as the main substance, but let's explicitly
    // pick it to test the dropdown interaction. Open the dropdown.
    await tester.tap(find.byType(DropdownButtonFormField<Substance>));
    await pumpAndWait(tester);

    //    Tap the "Caffeine" option in the dropdown menu.
    //    .last because the text appears in both the dropdown button and the menu overlay.
    await tester.tap(find.text('Caffeine').last);
    await pumpAndWait(tester);

    // 2. Enter amount "90".
    await tester.enterText(find.byType(TextField), '90');
    await tester.pump();

    // 3. Tap the "Log Dose" button (FilledButton, not the heading text).
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    // 4. Verify the dose was inserted in the database.
    //    Query the DB directly — like assertDatabaseHas() in Laravel.
    final logs = await db.select(db.doseLogs).get();
    expect(logs.length, 1);
    expect(logs.first.amount, 90.0);
    expect(logs.first.substanceId, 1); // Caffeine's auto-increment ID from onCreate seed

    // 5. Verify the form reset — amount field should be empty.
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, isEmpty);

    await cleanUp(tester);
  });

  testWidgets('save button is disabled when form is incomplete', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // The "Log Dose" button should be disabled (onPressed == null).
    // Even though Caffeine is auto-selected as main, no amount is entered.
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await cleanUp(tester);
  });

  testWidgets('save button is disabled with zero amount', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Caffeine is already auto-selected as main. Enter "0" — should still be disabled.
    await tester.enterText(find.byType(TextField), '0');
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await cleanUp(tester);
  });

  // --- Recent logs list tests ---

  testWidgets('shows empty state when no doses logged', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // The empty state text should appear since no doses exist yet.
    expect(find.text('No doses logged yet.'), findsOneWidget);
    // The "Recent Doses" heading should NOT appear when the list is empty.
    expect(find.text('Recent Doses'), findsNothing);

    await cleanUp(tester);
  });

  testWidgets('logged dose appears in recent logs list', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Caffeine is auto-selected as main. Enter amount and log.
    await tester.enterText(find.byType(TextField), '95');
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    // pump() to process the save, then pumpAndWait to let the stream
    // provider emit the updated list and rebuild the widget tree.
    await tester.pump();
    await pumpAndWait(tester);

    // The log entry should appear in the recent logs section.
    expect(find.text('Caffeine — 95 mg'), findsOneWidget);
    // The heading should appear now that there are logs.
    expect(find.text('Recent Doses'), findsOneWidget);
    // Empty state text should be gone.
    expect(find.text('No doses logged yet.'), findsNothing);

    await cleanUp(tester);
  });

  // --- Card.outlined styling tests ---

  testWidgets('log entries are wrapped in Card.outlined', (tester) async {
    // Insert a dose so we have a log entry to check.
    await db.insertDoseLog(1, 150, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Card.outlined creates a Card widget. Verify the ListTile is inside a Card.
    expect(
      find.ancestor(
        of: find.text('Caffeine — 150 mg'),
        matching: find.byType(Card),
      ),
      findsOneWidget,
    );

    await cleanUp(tester);
  });

  // --- Navigation to edit screen tests ---

  testWidgets('tapping a log entry navigates to EditDoseScreen', (tester) async {
    // Insert a dose so we have something to tap.
    await db.insertDoseLog(1, 120, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Tap the log entry's ListTile (not the delete button).
    await tester.tap(find.text('Caffeine — 120 mg'));

    // After Navigator.push, use bounded pumps. 500ms is enough for the
    // MaterialPageRoute transition animation (300ms).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // EditDoseScreen should now be in the widget tree.
    expect(find.byType(EditDoseScreen), findsOneWidget);
    expect(find.text('Edit Dose'), findsOneWidget);

    await cleanUp(tester, hasNavigated: true);
  });

  testWidgets('EditDoseScreen pre-fills form with existing data', (tester) async {
    // Insert a dose with a known amount.
    await db.insertDoseLog(1, 75, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Navigate to the edit screen.
    await tester.tap(find.text('Caffeine — 75 mg'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The amount field should be pre-filled with "75".
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, '75');

    // The substance dropdown should show "Caffeine" pre-selected.
    expect(find.text('Caffeine'), findsOneWidget);

    await cleanUp(tester, hasNavigated: true);
  });

  testWidgets('EditDoseScreen save updates the database and pops back', (tester) async {
    // Insert a dose to edit.
    await db.insertDoseLog(1, 100, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Navigate to edit screen.
    await tester.tap(find.text('Caffeine — 100 mg'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Change the amount from 100 to 200.
    await tester.enterText(find.byType(TextField), '200');
    await tester.pump();

    // Tap the "Save Changes" button.
    await tester.tap(find.byType(FilledButton));
    // pump() processes the save + Navigator.pop(), then pump with duration
    // for the reverse route animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Should have popped back to the log screen — EditDoseScreen gone.
    expect(find.byType(EditDoseScreen), findsNothing);
    expect(find.byType(LogDoseScreen), findsOneWidget);

    // Verify the database was updated — like assertDatabaseHas().
    final logs = await db.select(db.doseLogs).get();
    expect(logs.length, 1);
    expect(logs.first.amount, 200.0);

    await cleanUp(tester);
  });

  testWidgets('delete removes dose from list and database', (tester) async {
    // Insert a dose directly in the DB.
    await db.insertDoseLog(1, 200, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Verify the log entry appears in the UI.
    expect(find.text('Caffeine — 200 mg'), findsOneWidget);

    // Tap the delete button (the only IconButton with delete_outline icon).
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await pumpAndWait(tester);

    // Verify it's gone from the UI.
    expect(find.text('Caffeine — 200 mg'), findsNothing);
    // Empty state should return since there are no more logs.
    expect(find.text('No doses logged yet.'), findsOneWidget);

    // Verify it's gone from the database too — like assertDatabaseMissing().
    final logs = await db.select(db.doseLogs).get();
    expect(logs, isEmpty);

    await cleanUp(tester);
  });

  // --- Milestone 2b: Visibility + auto-select tests ---

  testWidgets('hidden substance does not appear in Log dropdown', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Open the substance dropdown.
    await tester.tap(find.byType(DropdownButtonFormField<Substance>));
    await pumpAndWait(tester);

    // Caffeine (visible) and Water (visible) should appear in the menu.
    // Alcohol (hidden) should NOT appear.
    // Each substance appears twice: once in the dropdown button, once in the menu.
    expect(find.text('Caffeine'), findsWidgets);
    expect(find.text('Water'), findsWidgets);
    expect(find.text('Alcohol'), findsNothing);

    // Close the dropdown by tapping outside it.
    await tester.tapAt(Offset.zero);
    await tester.pump();

    await cleanUp(tester);
  });

  testWidgets('main substance is auto-selected in dropdown', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Caffeine is seeded as isMain=true. The dropdown should show "Caffeine"
    // without the user needing to pick it — auto-selected during _buildForm.
    // The DropdownButtonFormField with value=Caffeine renders the text.
    expect(find.text('Caffeine'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('save works with auto-selected main substance', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Caffeine is auto-selected. Just enter an amount and save.
    await tester.enterText(find.byType(TextField), '100');
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    // Verify the dose was saved with Caffeine (id=1).
    final logs = await db.select(db.doseLogs).get();
    expect(logs.length, 1);
    expect(logs.first.substanceId, 1);
    expect(logs.first.amount, 100.0);

    await cleanUp(tester);
  });

  // --- Milestone 3: Dynamic unit suffix tests ---

  testWidgets('amount field shows substance unit as suffix', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Caffeine is auto-selected — its unit is "mg".
    // The amount TextField's suffixText should show "mg".
    final textField = tester.widget<TextField>(find.byType(TextField));
    final decoration = textField.decoration!;
    expect(decoration.suffixText, 'mg');

    await cleanUp(tester);
  });

  testWidgets('unit suffix changes when selecting different substance', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Caffeine is auto-selected (unit = "mg"). Switch to Water (unit = "ml").
    // Open the dropdown.
    await tester.tap(find.byType(DropdownButtonFormField<Substance>));
    await pumpAndWait(tester);

    // Tap "Water" in the dropdown menu.
    await tester.tap(find.text('Water').last);
    await pumpAndWait(tester);

    // Now the amount field should show "ml" as the suffix.
    final textField = tester.widget<TextField>(find.byType(TextField));
    final decoration = textField.decoration!;
    expect(decoration.suffixText, 'ml');

    await cleanUp(tester);
  });

  testWidgets('recent log entry shows substance unit', (tester) async {
    // Insert a Water dose (id=2, unit="ml") directly in the DB.
    await db.insertDoseLog(2, 500, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // The log tile should show "Water — 500 ml" (not "500 mg").
    expect(find.text('Water — 500 ml'), findsOneWidget);

    await cleanUp(tester);
  });
}
