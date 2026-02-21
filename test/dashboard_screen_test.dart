import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/dashboard_screen.dart';
import 'package:taper/screens/dashboard/widgets/trackable_card.dart';

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

  testWidgets('shows Today header with date navigation', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    // The header now shows "Today" (the date nav label) instead of "Dashboard".
    expect(find.text('Today'), findsOneWidget);
    // Date navigation arrows should be visible.
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows cards for visible trackables', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    expect(find.byType(TrackableCard), findsNWidgets(2));
    expect(find.text('Caffeine'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Alcohol'), findsNothing);

    await cleanUp(tester);
  });

  testWidgets('empty state when no visible trackables', (tester) async {
    // Hide both visible trackables using updateTrackable.
    await db.updateTrackable(1, isVisible: const Value(false));
    await db.updateTrackable(2, isVisible: const Value(false));

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.textContaining('No visible trackables'), findsOneWidget);
    expect(find.byType(TrackableCard), findsNothing);

    await cleanUp(tester);
  });

  testWidgets('card shows trackable name and stats with /', (tester) async {
    await db.insertDoseLog(1, 90, DateTime.now());

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    expect(find.text('Caffeine'), findsOneWidget);
    // Compact format: "active / total unit" — should contain "/".
    expect(find.textContaining('/'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('card shows just total for trackable without half-life', (tester) async {
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

  testWidgets('Add Dose dialog shows preset chips when presets exist', (tester) async {
    // Insert a preset for Caffeine (trackable ID = 1 from seeder).
    await db.insertPreset(1, 'Espresso', 90);

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    // Tap "Add Dose" on the Caffeine card.
    await tester.tap(find.text('Add Dose').first);
    await tester.pump();
    await pumpAndWait(tester);

    // The quick-add dialog should show the preset chip.
    expect(find.text('Log Caffeine'), findsOneWidget);
    // The chip shows "Espresso (90)".
    expect(find.text('Espresso (90)'), findsOneWidget);

    // Tap the chip — should fill the amount field.
    await tester.tap(find.text('Espresso (90)'));
    await tester.pump();

    // Find the TextField in the dialog and verify its controller text.
    final textField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
    );
    expect(textField.controller?.text, '90');

    // Dismiss dialog.
    await tester.tap(find.text('Cancel'));
    await tester.pump();

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

  testWidgets('View Log navigates to TrackableLogScreen', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    await tester.tap(find.text('View Log').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Caffeine'), findsWidgets);

    await cleanUp(tester, hasNavigated: true);
  });

  // --- Date navigation tests ---

  testWidgets('date nav shows "Today" by default', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    // The header should show "Today" as the date label.
    expect(find.text('Today'), findsOneWidget);
    // Left arrow should be enabled, right arrow should be disabled (on today).
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('left arrow navigates to previous day', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    // Tap the left arrow to go to the previous day.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    await pumpAndWaitLong(tester);

    // Should show "Yesterday" now, not "Today".
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Today'), findsNothing);

    await cleanUp(tester);
  });

  testWidgets('right arrow navigates back to today', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    // Go back one day.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    await pumpAndWaitLong(tester);

    expect(find.text('Yesterday'), findsOneWidget);

    // Go forward one day (back to today).
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    await pumpAndWaitLong(tester);

    expect(find.text('Today'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('past date shows old data', (tester) async {
    // Log a dose yesterday.
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await db.insertDoseLog(2, 750, yesterday);

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    // Today: Water card should show "0 ml" (no dose today).
    expect(find.text('0 ml'), findsOneWidget);

    // Navigate to yesterday.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    await pumpAndWaitLong(tester);

    // Yesterday: Water card should show "750 ml".
    expect(find.text('750 ml'), findsOneWidget);

    await cleanUp(tester);
  });

}
