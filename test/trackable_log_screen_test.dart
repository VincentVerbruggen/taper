import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/dashboard/trackable_log_screen.dart';
import 'package:taper/screens/log/edit_dose_screen.dart';

import 'helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late Trackable caffeine;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = createTestDatabase();
    final trackables = await db.select(db.trackables).get();
    caffeine = trackables.firstWhere((s) => s.name == 'Caffeine');
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
      child: MaterialApp(
        home: TrackableLogScreen(trackable: caffeine),
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

  testWidgets('shows trackable name in AppBar', (tester) async {
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

  testWidgets('swipe-to-delete removes dose and shows undo SnackBar', (tester) async {
    await db.insertDoseLog(caffeine.id, 100, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // 100 mg appears twice: once in the dose entry, once in the day total header.
    expect(find.text('100 mg'), findsNWidgets(2));

    // Fling the Dismissible widget (there's exactly one since we have one dose).
    // Can't use find.text('100 mg').first because the first match is the
    // day total header (not inside a Dismissible).
    await tester.fling(find.byType(Dismissible), const Offset(-500, 0), 1000);
    // Pump repeatedly to let dismiss animation finish, async DB delete complete,
    // and the StreamBuilder emit the updated empty list.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('100 mg'), findsNothing);
    expect(find.text('No doses logged yet.'), findsOneWidget);

    final logs = await db.select(db.doseLogs).get();
    expect(logs, isEmpty);

    // SnackBar with undo action.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('undo re-inserts deleted dose', (tester) async {
    await db.insertDoseLog(caffeine.id, 100, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.text('100 mg'), findsNWidgets(2));

    // Swipe to delete.
    await tester.fling(find.byType(Dismissible), const Offset(-500, 0), 1000);
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('100 mg'), findsNothing);

    // Tap "Undo" to re-insert.
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await pumpAndWait(tester);

    // Dose should be back — appears in entry + day total again.
    expect(find.text('100 mg'), findsNWidgets(2));

    final logs = await db.select(db.doseLogs).get();
    expect(logs.length, 1);
    expect(logs.first.amount, 100.0);

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

  // --- Date filter tests ---

  testWidgets('calendar icon is visible in AppBar', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Calendar icon should be in the AppBar for date filtering.
    expect(find.byIcon(Icons.calendar_today), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('selecting a date filters doses to that day', (tester) async {
    // Log doses on two different days.
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    await db.insertDoseLog(caffeine.id, 90, now);
    await db.insertDoseLog(caffeine.id, 60, yesterday);

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Both doses should be visible initially (infinite scroll loads recent history).
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);

    // Tap the calendar icon to open the date picker.
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pump();

    // The date picker dialog should appear.
    expect(find.byType(DatePickerDialog), findsOneWidget);

    // Tap OK to select today's date (the default initial date).
    await tester.tap(find.text('OK'));
    await tester.pump();
    await pumpAndWait(tester);

    // After selecting today, "Today" appears twice: AppBar subtitle + day header.
    // Yesterday's doses should be filtered out.
    expect(find.text('Today'), findsNWidgets(2));
    expect(find.text('Yesterday'), findsNothing);
    // The close button should appear to clear the filter.
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Tap close to go back to all history.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await pumpAndWait(tester);

    // Both days should be visible again. "Today" back to just the day header.
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    // Close button should be gone.
    expect(find.byIcon(Icons.close), findsNothing);

    await cleanUp(tester);
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
    expect(logs.first.trackableId, caffeine.id);

    await cleanUp(tester);
  });
}
