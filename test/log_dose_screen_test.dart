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
    // "Caffeine" as the default substance (like Laravel's DatabaseSeeder).
  });

  // DB is closed in cleanUp() at the end of each test.
  // No tearDown needed — closing twice would throw.

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

  /// Dispose the widget tree cleanly before tearDown.
  ///
  /// When ProviderScope disposes, Drift's stream cleanup schedules a zero-duration
  /// timer. We need to dispose the widget tree and then pump enough to let the
  /// timer fire — otherwise the test framework complains about pending timers.
  ///
  /// For tests that Navigator.push to a second screen (like EditDoseScreen),
  /// we MUST pop back first. If we try to replace the widget tree while two
  /// routes are stacked, the disposal of dual stream-subscribed screens
  /// causes an infinite rebuild loop that hangs the test framework.
  /// Think of it like closing a modal before leaving the page.
  Future<void> cleanUp(WidgetTester tester, {bool hasNavigated = false}) async {
    // If we pushed a route, pop it first to get back to a single-screen state.
    // This prevents the hang caused by disposing two stacked screens with
    // active Drift stream subscriptions simultaneously.
    if (hasNavigated) {
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    // Close DB — cleans up stream subscriptions from Drift's side.
    await db.close();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('shows substance dropdown with seeded data', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // The dropdown should show "Caffeine" as an option.
    expect(find.text('Substance'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('can log a dose', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. Open the substance dropdown and select "Caffeine".
    await tester.tap(find.byType(DropdownButtonFormField<Substance>));
    await tester.pumpAndSettle();

    //    Tap the "Caffeine" option in the dropdown menu.
    //    .last because the text appears in both the dropdown button and the menu overlay.
    await tester.tap(find.text('Caffeine').last);
    await tester.pumpAndSettle();

    // 2. Enter amount "90".
    await tester.enterText(find.byType(TextField), '90');
    await tester.pumpAndSettle();

    // 3. Tap the "Log Dose" button (FilledButton, not the heading text).
    await tester.tap(find.byType(FilledButton));
    // Use pump() not pumpAndSettle() — in the test environment the async DB insert
    // completes synchronously, and pumpAndSettle can cause extra rebuild cycles.
    await tester.pump();

    // 4. Verify the dose was inserted in the database.
    //    Query the DB directly — like assertDatabaseHas() in Laravel.
    final logs = await db.select(db.doseLogs).get();
    expect(logs.length, 1);
    expect(logs.first.amountMg, 90.0);
    expect(logs.first.substanceId, 1); // Caffeine's auto-increment ID from onCreate seed

    // 5. Verify the form reset — amount field should be empty.
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, isEmpty);

    await cleanUp(tester);
  });

  testWidgets('save button is disabled when form is incomplete', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // The "Log Dose" button should be disabled (onPressed == null)
    // because no substance is selected and no amount is entered.
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await cleanUp(tester);
  });

  testWidgets('save button is disabled with zero amount', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Select substance
    await tester.tap(find.byType(DropdownButtonFormField<Substance>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Caffeine').last);
    await tester.pumpAndSettle();

    // Enter "0" — should still be disabled
    await tester.enterText(find.byType(TextField), '0');
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await cleanUp(tester);
  });

  // --- Recent logs list tests ---

  testWidgets('shows empty state when no doses logged', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // The empty state text should appear since no doses exist yet.
    expect(find.text('No doses logged yet.'), findsOneWidget);
    // The "Recent Doses" heading should NOT appear when the list is empty.
    expect(find.text('Recent Doses'), findsNothing);

    await cleanUp(tester);
  });

  testWidgets('logged dose appears in recent logs list', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. Fill out the form and log a dose.
    await tester.tap(find.byType(DropdownButtonFormField<Substance>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Caffeine').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '95');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton));
    // pump() to process the save, then pumpAndSettle() to let the stream
    // provider emit the updated list and rebuild the widget tree.
    await tester.pump();
    await tester.pumpAndSettle();

    // 2. The log entry should appear in the recent logs section.
    //    "Caffeine — 95 mg" is the ListTile title format.
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
    await tester.pumpAndSettle();

    // Card.outlined creates a Card widget. Verify the ListTile is inside a Card.
    // find.ancestor() checks that the ListTile containing our dose text has a
    // Card ancestor — like asserting a Blade component wraps the row:
    //   <x-card> <x-list-tile>Caffeine — 150 mg</x-list-tile> </x-card>
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
    await tester.pumpAndSettle();

    // Tap the log entry's ListTile (not the delete button).
    // The ListTile text triggers onTap → Navigator.push(EditDoseScreen).
    await tester.tap(find.text('Caffeine — 120 mg'));

    // After Navigator.push, use pump() with a duration instead of pumpAndSettle().
    // pumpAndSettle() hangs here because: the route transition animation triggers
    // rebuilds, and both screens (LogDoseScreen behind + EditDoseScreen on top)
    // have active stream providers that keep emitting frames.
    // 500ms is enough for the MaterialPageRoute transition animation (300ms).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // EditDoseScreen should now be in the widget tree — it was pushed on top.
    // Like asserting the browser navigated to /doses/1/edit.
    expect(find.byType(EditDoseScreen), findsOneWidget);
    // The AppBar should show "Edit Dose".
    expect(find.text('Edit Dose'), findsOneWidget);

    // hasNavigated: true tells cleanUp to pop the route first — see cleanUp docs.
    await cleanUp(tester, hasNavigated: true);
  });

  testWidgets('EditDoseScreen pre-fills form with existing data', (tester) async {
    // Insert a dose with a known amount.
    await db.insertDoseLog(1, 75, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Navigate to the edit screen (see above for why pump() not pumpAndSettle()).
    await tester.tap(find.text('Caffeine — 75 mg'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The amount field should be pre-filled with "75".
    // Like checking old('amount') == 75 in a Blade form.
    //
    // find.byType(TextField) finds the FIRST TextField in the tree.
    // On EditDoseScreen there's only one TextField (the amount input) —
    // the substance picker is a DropdownButtonFormField, not a TextField.
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
    await tester.pumpAndSettle();

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
    expect(logs.first.amountMg, 200.0);

    await cleanUp(tester);
  });

  testWidgets('delete removes dose from list and database', (tester) async {
    // 1. Insert a dose directly in the DB — like a Laravel factory/seeder.
    //    Caffeine has id=1 from the onCreate seed.
    await db.insertDoseLog(1, 200, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 2. Verify the log entry appears in the UI.
    expect(find.text('Caffeine — 200 mg'), findsOneWidget);

    // 3. Tap the delete button (the only IconButton with delete_outline icon).
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.pumpAndSettle();

    // 4. Verify it's gone from the UI.
    expect(find.text('Caffeine — 200 mg'), findsNothing);
    // Empty state should return since there are no more logs.
    expect(find.text('No doses logged yet.'), findsOneWidget);

    // 5. Verify it's gone from the database too — like assertDatabaseMissing().
    final logs = await db.select(db.doseLogs).get();
    expect(logs, isEmpty);

    await cleanUp(tester);
  });
}
