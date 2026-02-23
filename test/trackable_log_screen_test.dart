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
    final now = DateTime(2026, 2, 23, 12); // Noon
    await db.insertDoseLog(caffeine.id, 90, now);
    await db.insertDoseLog(caffeine.id, 90, now.subtract(const Duration(hours: 1)));

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('90 mg'), findsNWidgets(2));

    await cleanUp(tester);
  });

  testWidgets('daily total shown in header', (tester) async {
    final now = DateTime(2026, 2, 23, 12); // Noon
    await db.insertDoseLog(caffeine.id, 90, now);
    await db.insertDoseLog(caffeine.id, 60, now.subtract(const Duration(hours: 1)));

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.textContaining('150'), findsOneWidget);
    expect(find.textContaining('mg'), findsWidgets);

    await cleanUp(tester);
  });

  testWidgets('shows tapering target when plan exists', (tester) async {
    final now = DateTime(2026, 2, 23, 12);
    final boundaryHour = 5;
    final boundary = DateTime(now.year, now.month, now.day, boundaryHour);
    
    // Insert a tapering plan for caffeine.
    await db.insertTaperPlan(
      caffeine.id,
      400,
      100,
      boundary,
      boundary.add(const Duration(days: 30)),
    );
    
    await db.insertDoseLog(caffeine.id, 90, now);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Should show "90 / 400 mg" in the header.
    expect(find.text('90'), findsOneWidget);
    expect(find.text(' / 400'), findsOneWidget);
    expect(find.text('mg'), findsWidgets);

    await cleanUp(tester);
  });

  testWidgets('tap delete icon removes dose and shows undo SnackBar', (tester) async {
    final now = DateTime(2026, 2, 23, 12);
    await db.insertDoseLog(caffeine.id, 100, now);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // "100" appears in the header and "100 mg" appears in the dose entry.
    expect(find.textContaining('100'), findsNWidgets(2));

    // Tap the delete icon button.
    await tester.tap(find.byIcon(Icons.delete_outline));
    
    // Wait for animation and DB update.
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(ListView), matching: find.textContaining('100')),
      findsNothing,
    );
    expect(find.text('No doses logged yet.'), findsOneWidget);

    final logs = await db.select(db.doseLogs).get();
    expect(logs, isEmpty);

    // SnackBar with undo action.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('undo re-inserts deleted dose', (tester) async {
    final now = DateTime(2026, 2, 23, 12);
    await db.insertDoseLog(caffeine.id, 100, now);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.textContaining('100'), findsNWidgets(2));

    // Tap delete.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(ListView), matching: find.textContaining('100')),
      findsNothing,
    );

    // Tap "Undo" to re-insert.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    // Dose should be back.
    expect(find.textContaining('100'), findsNWidgets(2));

    final logs = await db.select(db.doseLogs).get();
    expect(logs.length, 1);
    expect(logs.first.amount, 100.0);

    await cleanUp(tester);
  });

  testWidgets('tap navigates to edit screen', (tester) async {
    await db.insertDoseLog(caffeine.id, 75, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(
      find.ancestor(
        of: find.text('75 mg'),
        matching: find.byType(ListTile),
      ),
    );
    await tester.pumpAndSettle();

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
    final now = DateTime(2026, 2, 23, 12);
    final yesterday = now.subtract(const Duration(days: 1));
    await db.insertDoseLog(caffeine.id, 90, now);
    await db.insertDoseLog(caffeine.id, 60, yesterday);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Both doses should be visible initially (infinite scroll loads recent history).
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);

    // Tap the calendar icon to open the date picker.
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();

    // The CalendarDatePicker dialog should appear.
    expect(find.byType(CalendarDatePicker), findsOneWidget);

    // Tap today's day number to select it.
    final today = now.day.toString();
    await tester.tap(find.text(today).last);
    await tester.pumpAndSettle();

    // After selecting today, "Today" appears twice: AppBar subtitle + day header.
    // Yesterday's doses should be filtered out.
    expect(find.text('Today'), findsNWidgets(2));
    expect(find.text('Yesterday'), findsNothing);
    // The close button should appear to clear the filter.
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Tap close to go back to all history.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Both days should be visible again.
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);

    await cleanUp(tester);
  });

  // --- FAB + quick-add dialog tests ---

  testWidgets('FAB opens quick-add dialog', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Log Caffeine'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await cleanUp(tester);
  });

  testWidgets('quick-add dialog logs dose and closes', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '200');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();

    // Dialog should be dismissed.
    expect(find.text('Log Caffeine'), findsNothing);

    // Verify dose was inserted.
    final logs = await db.select(db.doseLogs).get();
    expect(logs.any((l) => l.amount == 200), isTrue);

    await cleanUp(tester);
  });

  testWidgets('zero-dose shows "Skipped" instead of amount', (tester) async {
    final now = DateTime(2026, 2, 23, 12);
    await db.insertDoseLog(caffeine.id, 0, now);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Should show "Skipped" for zero-dose entries.
    expect(find.text('Skipped'), findsOneWidget);

    await cleanUp(tester);
  });
}
