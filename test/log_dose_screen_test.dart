import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/log/add_dose_screen.dart';
import 'package:taper/screens/log/edit_dose_screen.dart';
import 'package:taper/screens/log/log_dose_screen.dart';

import 'helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

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

  testWidgets('recent log entry shows trackable unit', (tester) async {
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

  testWidgets('swipe-to-delete removes dose and shows undo SnackBar', (tester) async {
    await db.insertDoseLog(1, 200, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.text('Caffeine — 200 mg'), findsOneWidget);

    // Fling (fast swipe) the dose entry from right to left to trigger dismiss.
    // fling() is like a fast drag gesture — the Offset is the direction vector.
    await tester.fling(find.text('Caffeine — 200 mg'), const Offset(-500, 0), 1000);
    // Pump repeatedly to let the dismiss animation finish, the async DB delete
    // complete, and the Riverpod stream emit the updated list.
    // onDismissed fires a void callback that starts an async delete — we need
    // multiple pump cycles to let the Future resolve and the stream propagate.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Dose should be gone from the list AND the database.
    expect(find.text('Caffeine — 200 mg'), findsNothing);

    final logs = await db.select(db.doseLogs).get();
    expect(logs, isEmpty);

    // SnackBar should show with "Undo" action.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('undo re-inserts deleted dose', (tester) async {
    await db.insertDoseLog(1, 300, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.text('Caffeine — 300 mg'), findsOneWidget);

    // Swipe to delete.
    await tester.fling(find.text('Caffeine — 300 mg'), const Offset(-500, 0), 1000);
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Dose should be gone.
    expect(find.text('Caffeine — 300 mg'), findsNothing);

    // Tap "Undo" to re-insert.
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await pumpAndWait(tester);

    // Dose should be back in the list and database.
    expect(find.text('Caffeine — 300 mg'), findsOneWidget);

    final logs = await db.select(db.doseLogs).get();
    expect(logs.length, 1);
    expect(logs.first.amount, 300.0);

    await cleanUp(tester);
  });

  // --- Copy dose tests ---

  testWidgets('copy icon appears on dose entries', (tester) async {
    await db.insertDoseLog(1, 100, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // The copy icon should be visible on the dose entry.
    expect(find.byIcon(Icons.copy), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('copy dose opens AddDoseScreen with pre-filled amount', (tester) async {
    await db.insertDoseLog(1, 250, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Tap the copy icon on the dose entry.
    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await pumpAndWait(tester);

    // Should be on AddDoseScreen with the amount pre-filled.
    expect(find.byType(AddDoseScreen), findsOneWidget);
    expect(find.text('250'), findsOneWidget);

    await cleanUp(tester, hasNavigated: true);
  });

  // --- Add dose screen tests ---

  testWidgets('FAB navigates to AddDoseScreen', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Tap the FAB to navigate to the add dose screen.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await pumpAndWait(tester);

    // Should be on the AddDoseScreen with the form fields.
    expect(find.byType(AddDoseScreen), findsOneWidget);
    // "Log Dose" in the AppBar title AND as the FilledButton label.
    expect(find.text('Log Dose'), findsNWidgets(2));
    // Trackable dropdown + amount field.
    expect(find.text('Trackable'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);

    await cleanUp(tester, hasNavigated: true);
  });

  testWidgets('save works with auto-selected trackable (first visible)', (tester) async {
    // No doses logged yet, so it falls back to first visible trackable (Caffeine).
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Navigate to the add dose screen.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await pumpAndWait(tester);

    // Caffeine is auto-selected (first visible trackable). Enter amount and save.
    await tester.enterText(find.byType(TextField).first, '100');
    await tester.pump();

    // Scroll the save button into view (may be off-screen in 600px viewport).
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await pumpAndWait(tester);

    // Verify the dose was saved for Caffeine (id=1).
    final logs = await db.select(db.doseLogs).get();
    expect(logs.length, 1);
    expect(logs.first.trackableId, 1);
    expect(logs.first.amount, 100.0);

    await cleanUp(tester);
  });

  // --- Zero-dose display tests ---

  testWidgets('zero-dose shows "Skipped" instead of amount', (tester) async {
    // A dose with amount=0 means "I explicitly skipped this" — like a nullable
    // boolean where null = no entry and false = skipped. The UI should show
    // "Skipped" instead of "0 mg" to make the intent clear.
    await db.insertDoseLog(1, 0, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Should show "Skipped" for zero-dose entries.
    expect(find.text('Caffeine — Skipped'), findsOneWidget);
    // Should NOT show "0 mg" — that would be confusing.
    expect(find.text('Caffeine — 0 mg'), findsNothing);

    await cleanUp(tester);
  });
}
