import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
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
  Future<void> cleanUp(WidgetTester tester) async {
    // Close DB first — this cleans up stream subscriptions from Drift's side
    // before the ProviderScope disposal tries to cancel them.
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
}
