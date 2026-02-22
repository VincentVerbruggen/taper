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

  testWidgets('shows edit icon in normal mode', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    // Edit mode toggle icon should be visible at the top.
    expect(find.byIcon(Icons.edit), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows cards for seeded dashboard widgets', (tester) async {
    // The onCreate seeder inserts 2 dashboard widgets (Caffeine + Water decay cards).
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    // Both TrackableCards should render from the dashboard widgets.
    expect(find.byType(TrackableCard), findsNWidgets(2));
    expect(find.text('Caffeine'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    // Alcohol is hidden and has no widget — shouldn't appear.
    expect(find.text('Alcohol'), findsNothing);

    await cleanUp(tester);
  });

  testWidgets('empty state when no dashboard widgets', (tester) async {
    // Delete all dashboard widgets.
    final widgets = await db.select(db.dashboardWidgets).get();
    for (final w in widgets) {
      await db.deleteDashboardWidget(w.id);
    }

    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.textContaining('No dashboard widgets'), findsOneWidget);
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

  // --- Edit mode tests ---

  testWidgets('edit mode toggle shows/hides drag handles', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    // Normal mode: no drag handles visible.
    expect(find.byIcon(Icons.drag_handle), findsNothing);

    // Tap the edit icon to enter edit mode.
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();
    await pumpAndWait(tester);

    // Edit mode: drag handles should appear for each widget (Caffeine + Water).
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
    // The edit icon should now be a check icon (done editing).
    expect(find.byIcon(Icons.check), findsOneWidget);
    // Should have delete buttons (X icons) for each widget.
    expect(find.byIcon(Icons.close), findsNWidgets(2));
    // "Add Widget" button should be visible.
    expect(find.text('Add Widget'), findsOneWidget);

    // Tap check to exit edit mode.
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    await pumpAndWait(tester);

    // Back to normal mode: drag handles gone.
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(find.byIcon(Icons.edit), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('add widget dialog shows type options', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    // Enter edit mode.
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();
    await pumpAndWait(tester);

    // Tap "Add Widget".
    await tester.tap(find.text('Add Widget'));
    await tester.pump();

    // Dialog should show all widget type options.
    // "Decay Card" also appears as subtitle labels in edit mode (2 widgets),
    // so we check the dialog contains the option using findsWidgets.
    expect(find.text('Decay Card'), findsWidgets); // 2 edit labels + 1 dialog option
    expect(find.text('Taper Progress'), findsOneWidget); // only in dialog
    expect(find.text('Daily Totals'), findsOneWidget); // new type
    expect(find.text('Decay Card (Enhanced)'), findsOneWidget); // new type

    // Dismiss by tapping outside.
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();

    await cleanUp(tester);
  });

  testWidgets('delete widget removes card from dashboard', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWaitLong(tester);

    // Should start with 2 cards.
    expect(find.byType(TrackableCard), findsNWidgets(2));

    // Enter edit mode.
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();
    await pumpAndWait(tester);

    // Delete the first widget (Caffeine).
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();
    await pumpAndWait(tester);

    // Exit edit mode.
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    await pumpAndWaitLong(tester);

    // Only 1 card should remain (Water).
    expect(find.byType(TrackableCard), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);

    await cleanUp(tester);
  });
}
