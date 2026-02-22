import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/trackables/edit_trackable_screen.dart';
import 'package:taper/screens/trackables/widgets/color_palette_selector.dart';

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

  /// Build a test widget wrapping EditTrackableScreen with a given trackable.
  Widget buildTestWidget(Trackable trackable) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: EditTrackableScreen(trackable: trackable),
      ),
    );
  }

  Future<void> pumpAndWait(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> cleanUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await db.close();
    await tester.pump();
  }

  // Helper to get the seeded Caffeine trackable.
  Future<Trackable> getCaffeine() async {
    final trackables = await db.select(db.trackables).get();
    return trackables.firstWhere((s) => s.name == 'Caffeine');
  }

  // Helper to get the seeded Alcohol trackable.
  Future<Trackable> getAlcohol() async {
    final trackables = await db.select(db.trackables).get();
    return trackables.firstWhere((s) => s.name == 'Alcohol');
  }

  // Helper to get the seeded Water trackable.
  Future<Trackable> getWater() async {
    final trackables = await db.select(db.trackables).get();
    return trackables.firstWhere((s) => s.name == 'Water');
  }

  // --- Basic rendering tests ---

  testWidgets('shows Edit Trackable title', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    expect(find.text('Edit Trackable'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('pre-fills name and unit for Caffeine', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    final textFields = find.byType(TextField);
    final nameField = tester.widget<TextField>(textFields.at(0));
    expect(nameField.controller?.text, 'Caffeine');
    final unitField = tester.widget<TextField>(textFields.at(1));
    expect(unitField.controller?.text, 'mg');

    await cleanUp(tester);
  });

  // --- Decay model dropdown tests ---

  testWidgets('shows exponential decay model for Caffeine', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // The dropdown should show "Exponential (half-life)" as selected.
    expect(find.text('Exponential (half-life)'), findsOneWidget);
    // Half-life field should be visible.
    expect(find.text('Half-life (hours)'), findsOneWidget);
    // Elimination rate field should NOT be visible.
    expect(find.textContaining('Elimination rate'), findsNothing);

    await cleanUp(tester);
  });

  testWidgets('shows linear decay model for Alcohol', (tester) async {
    final alcohol = await getAlcohol();
    await tester.pumpWidget(buildTestWidget(alcohol));
    await pumpAndWait(tester);

    // The dropdown should show "Linear (constant rate)" as selected.
    expect(find.text('Linear (constant rate)'), findsOneWidget);
    // Elimination rate field should be visible.
    expect(find.textContaining('Elimination rate'), findsOneWidget);
    // Half-life field should NOT be visible.
    expect(find.text('Half-life (hours)'), findsNothing);

    await cleanUp(tester);
  });

  testWidgets('shows none decay model for Water', (tester) async {
    final water = await getWater();
    await tester.pumpWidget(buildTestWidget(water));
    await pumpAndWait(tester);

    // The dropdown should show "None" as selected.
    expect(find.text('None'), findsOneWidget);
    // Neither half-life nor elimination rate should be visible.
    expect(find.text('Half-life (hours)'), findsNothing);
    expect(find.textContaining('Elimination rate'), findsNothing);

    await cleanUp(tester);
  });

  // --- Visibility toggle ---

  testWidgets('visibility toggle reflects trackable state', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Caffeine is visible by default — switch should be on.
    expect(find.text('Visible in log form'), findsOneWidget);
    // Find the visibility SwitchListTile specifically (not the cumulative toggle).
    final visibilitySwitch = find.widgetWithText(SwitchListTile, 'Visible in log form');
    expect(visibilitySwitch, findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('visibility toggle for hidden trackable shows off', (tester) async {
    final alcohol = await getAlcohol();
    await tester.pumpWidget(buildTestWidget(alcohol));
    await pumpAndWait(tester);

    // Alcohol is hidden (isVisible = false) — the visibility switch should be off.
    // Use text matcher to find the specific SwitchListTile (not the cumulative toggle).
    final visibilitySwitch = find.widgetWithText(SwitchListTile, 'Visible in log form');
    final switchWidget = tester.widget<SwitchListTile>(visibilitySwitch);
    expect(switchWidget.value, false);

    await cleanUp(tester);
  });

  // --- Delete button tests ---

  testWidgets('shows delete button', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Scroll down to find the delete button.
    await tester.ensureVisible(find.text('Delete Trackable'));
    expect(find.text('Delete Trackable'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('delete shows confirmation dialog', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Scroll to and tap the delete button.
    await tester.ensureVisible(find.text('Delete Trackable'));
    await tester.tap(find.text('Delete Trackable'));
    await tester.pump();

    // Should show a confirmation dialog.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Delete "Caffeine"'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // Cancel the dialog.
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    // Should still be on the edit screen.
    expect(find.byType(EditTrackableScreen), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('confirming delete removes trackable', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Scroll to and tap the delete button.
    await tester.ensureVisible(find.text('Delete Trackable'));
    await tester.tap(find.text('Delete Trackable'));
    await tester.pump();

    // Confirm delete.
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await pumpAndWait(tester);

    // Verify trackable was deleted from database.
    final trackables = await db.select(db.trackables).get();
    expect(trackables.where((s) => s.name == 'Caffeine'), isEmpty);

    await cleanUp(tester);
  });

  // --- Color picker tests ---

  testWidgets('shows 10 color circles from palette', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // ColorPaletteSelector should render with 10 color circles.
    expect(find.byType(ColorPaletteSelector), findsOneWidget);
    // Each color is a GestureDetector wrapping a Container.
    // There should be exactly 10 (one per palette color).
    final gestureDetectors = find.descendant(
      of: find.byType(ColorPaletteSelector),
      matching: find.byType(GestureDetector),
    );
    expect(gestureDetectors, findsNWidgets(10));

    await cleanUp(tester);
  });

  testWidgets('selected color shows check icon', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Caffeine's color is trackableColorPalette[0] = Green.
    // The selected circle should show a check icon.
    expect(
      find.descendant(
        of: find.byType(ColorPaletteSelector),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );

    await cleanUp(tester);
  });

  testWidgets('tapping a different color selects it and saving persists it', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Caffeine starts with palette[0] (Green = 0xFF4CAF50).
    // Tap the second color circle (Blue = 0xFF2196F3).
    final gestureDetectors = find.descendant(
      of: find.byType(ColorPaletteSelector),
      matching: find.byType(GestureDetector),
    );
    await tester.tap(gestureDetectors.at(1));
    await tester.pump();

    // Check icon should still appear (now on the blue circle).
    expect(
      find.descendant(
        of: find.byType(ColorPaletteSelector),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );

    // Save the changes.
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    await pumpAndWait(tester);

    // Verify the color was updated to Blue (palette[1]).
    final trackables = await db.select(db.trackables).get();
    final updated = trackables.firstWhere((s) => s.name == 'Caffeine');
    expect(updated.color, trackableColorPalette[1]);

    await cleanUp(tester);
  });

  // --- Save tests ---

  testWidgets('save updates trackable in database', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Change the name.
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Espresso');
    await tester.pump();

    // Scroll to and tap save.
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    await pumpAndWait(tester);

    // Verify the name was updated.
    final trackables = await db.select(db.trackables).get();
    expect(trackables.where((s) => s.name == 'Espresso'), isNotEmpty);
    expect(trackables.where((s) => s.name == 'Caffeine'), isEmpty);

    await cleanUp(tester);
  });

  // --- Preset management tests ---

  testWidgets('shows Presets section with "No presets yet"', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // The Presets header and empty state should be visible.
    expect(find.text('Presets'), findsOneWidget);
    expect(find.text('No presets yet'), findsOneWidget);
    expect(find.text('Add Preset'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('add a preset via dialog and it appears in list', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Tap "Add Preset" to open the dialog.
    await tester.tap(find.text('Add Preset'));
    await tester.pump();

    // The dialog should be visible with name and amount fields.
    expect(find.text('Add Preset'), findsNWidgets(2)); // Header + button.
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);

    // Fill in the dialog fields.
    // Find TextFields inside the dialog (AlertDialog).
    final dialogTextFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogTextFields.at(0), 'Espresso');
    await tester.enterText(dialogTextFields.at(1), '90');
    await tester.pump();

    // Tap "Add" to insert the preset.
    // The dialog has Cancel and Add buttons; find Add inside the dialog.
    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await tester.pump();
    await pumpAndWait(tester);

    // The preset should now appear in the list.
    expect(find.text('Espresso'), findsOneWidget);
    // "No presets yet" should be gone.
    expect(find.text('No presets yet'), findsNothing);

    // Verify it was actually inserted in the database.
    final presetRows = await db.select(db.presets).get();
    expect(presetRows.length, 1);
    expect(presetRows.first.name, 'Espresso');
    expect(presetRows.first.amount, 90.0);

    await cleanUp(tester);
  });

  testWidgets('delete a preset removes it from list', (tester) async {
    final caffeine = await getCaffeine();
    // Pre-insert a preset directly in the database.
    await db.insertPreset(caffeine.id, 'Espresso', 90);
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // The preset should be visible.
    expect(find.text('Espresso'), findsOneWidget);

    // Tap the delete icon button (trailing on the preset ListTile).
    // Find the delete icon inside the presets section.
    final deleteIcon = find.widgetWithIcon(IconButton, Icons.delete_outline);
    expect(deleteIcon, findsOneWidget);
    await tester.tap(deleteIcon);
    await tester.pump();
    await pumpAndWait(tester);

    // The preset should be gone, replaced by "No presets yet".
    expect(find.text('Espresso'), findsNothing);
    expect(find.text('No presets yet'), findsOneWidget);

    // Verify it was deleted from the database.
    final presetRows = await db.select(db.presets).get();
    expect(presetRows, isEmpty);

    await cleanUp(tester);
  });

  // --- Save tests (below) ---

  // --- Threshold management tests ---

  testWidgets('shows Thresholds section with "No thresholds yet"', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Scroll to the thresholds section (below presets).
    await tester.ensureVisible(find.text('Thresholds'));
    expect(find.text('Thresholds'), findsOneWidget);
    expect(find.text('No thresholds yet'), findsOneWidget);
    expect(find.text('Add Threshold'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('add a threshold via dialog and it appears in list', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Scroll to and tap "Add Threshold".
    await tester.ensureVisible(find.text('Add Threshold'));
    await tester.tap(find.text('Add Threshold'));
    await tester.pump();

    // The dialog should be visible.
    expect(find.text('Add Threshold'), findsNWidgets(2)); // Header + button.
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);

    // Fill in the dialog fields.
    final dialogTextFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogTextFields.at(0), 'Daily max');
    await tester.enterText(dialogTextFields.at(1), '400');
    await tester.pump();

    // Tap "Add".
    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await tester.pump();
    await pumpAndWait(tester);

    // The threshold should now appear in the list.
    expect(find.text('Daily max'), findsOneWidget);
    // "No thresholds yet" should be gone.
    expect(find.text('No thresholds yet'), findsNothing);

    // Verify it was inserted in the database.
    final thresholdRows = await db.select(db.thresholds).get();
    expect(thresholdRows.length, 1);
    expect(thresholdRows.first.name, 'Daily max');
    expect(thresholdRows.first.amount, 400.0);

    await cleanUp(tester);
  });

  testWidgets('delete a threshold removes it from list', (tester) async {
    final caffeine = await getCaffeine();
    // Pre-insert a threshold directly in the database.
    await db.insertThreshold(caffeine.id, 'Daily max', 400);
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Scroll to make threshold visible.
    await tester.ensureVisible(find.text('Daily max'));
    expect(find.text('Daily max'), findsOneWidget);

    // Tap the delete icon button. There might be one from presets too,
    // so find the one associated with "Daily max".
    final deleteIcons = find.widgetWithIcon(IconButton, Icons.delete_outline);
    // Should have at least one (the threshold delete).
    expect(deleteIcons, findsWidgets);
    await tester.tap(deleteIcons.last);
    await tester.pump();
    await pumpAndWait(tester);

    // The threshold should be gone.
    expect(find.text('Daily max'), findsNothing);
    expect(find.text('No thresholds yet'), findsOneWidget);

    // Verify it was deleted from the database.
    final thresholdRows = await db.select(db.thresholds).get();
    expect(thresholdRows, isEmpty);

    await cleanUp(tester);
  });

  // --- Save tests (continued) ---

  testWidgets('save with visibility off updates isVisible', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Scroll to and toggle visibility off.
    // Find the specific visibility SwitchListTile (not the cumulative toggle).
    final visibilitySwitch = find.widgetWithText(SwitchListTile, 'Visible in log form');
    await tester.ensureVisible(visibilitySwitch);
    await tester.tap(visibilitySwitch);
    await tester.pump();

    // Save.
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    await pumpAndWait(tester);

    // Verify visibility was updated.
    final trackables = await db.select(db.trackables).get();
    final caffeine2 = trackables.firstWhere((s) => s.name == 'Caffeine');
    expect(caffeine2.isVisible, false);

    await cleanUp(tester);
  });

  // --- Cumulative intake toggle tests ---

  testWidgets('cumulative toggle visible for trackable with decay model', (tester) async {
    // Caffeine has exponential decay, so the cumulative toggle should appear.
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Scroll to make the toggle visible (it's below the absorption field).
    final cumulativeSwitch = find.widgetWithText(SwitchListTile, 'Show cumulative intake');
    await tester.ensureVisible(cumulativeSwitch);
    expect(cumulativeSwitch, findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('cumulative toggle hidden for trackable without decay model', (tester) async {
    // Water has decay model = none, so the cumulative toggle should not appear.
    final water = await getWater();
    await tester.pumpWidget(buildTestWidget(water));
    await pumpAndWait(tester);

    expect(find.text('Show cumulative intake'), findsNothing);

    await cleanUp(tester);
  });

  testWidgets('cumulative toggle defaults to off and saves correctly', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // The toggle should default to off (showCumulativeLine = false for seeded data).
    final cumulativeSwitch = find.widgetWithText(SwitchListTile, 'Show cumulative intake');
    await tester.ensureVisible(cumulativeSwitch);
    final switchWidget = tester.widget<SwitchListTile>(cumulativeSwitch);
    expect(switchWidget.value, false);

    // Toggle it on.
    await tester.tap(cumulativeSwitch);
    await tester.pump();

    // Save changes.
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    await pumpAndWait(tester);

    // Verify the flag was persisted in the database.
    final trackables = await db.select(db.trackables).get();
    final updated = trackables.firstWhere((t) => t.name == 'Caffeine');
    expect(updated.showCumulativeLine, true);

    await cleanUp(tester);
  });

  // --- Taper plans section tests ---

  testWidgets('shows "No taper plans yet" for trackable without plans', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Scroll to find the taper plans section.
    final taperPlansLabel = find.text('Taper Plans');
    await tester.ensureVisible(taperPlansLabel);
    expect(taperPlansLabel, findsOneWidget);
    expect(find.text('No taper plans yet'), findsOneWidget);
    expect(find.text('New Taper Plan'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('"New Taper Plan" button is visible and navigates', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Scroll to and tap "New Taper Plan".
    final button = find.text('New Taper Plan');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await pumpAndWait(tester);

    // Should navigate to the AddTaperPlanScreen.
    expect(find.text('New Taper Plan'), findsWidgets); // Title + button text
    expect(find.text('Start amount'), findsOneWidget);
    expect(find.text('Target amount'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('plan list renders after adding a plan', (tester) async {
    final caffeine = await getCaffeine();
    // Pre-insert a taper plan directly in the database.
    await db.insertTaperPlan(
      caffeine.id,
      400,
      100,
      DateTime(2026, 2, 1, 5),
      DateTime(2026, 3, 1, 5),
    );
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Scroll to the taper plans section.
    final taperPlansLabel = find.text('Taper Plans');
    await tester.ensureVisible(taperPlansLabel);

    // The plan should be visible with its amount range.
    expect(find.textContaining('400'), findsWidgets);
    expect(find.textContaining('100'), findsWidgets);
    // "No taper plans yet" should NOT be shown.
    expect(find.text('No taper plans yet'), findsNothing);
    // Status should be "Active".
    expect(find.textContaining('Active'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('delete removes plan from list', (tester) async {
    final caffeine = await getCaffeine();
    // Pre-insert a taper plan.
    await db.insertTaperPlan(
      caffeine.id,
      400,
      100,
      DateTime(2026, 2, 1, 5),
      DateTime(2026, 3, 1, 5),
    );
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Scroll to the taper plans section.
    final taperPlansLabel = find.text('Taper Plans');
    await tester.ensureVisible(taperPlansLabel);

    // Find and tap the delete icon for the taper plan.
    // There should be one delete icon in the taper plans section.
    // We need the one with Icons.delete_outline that's inside the taper plans section.
    final deleteIcons = find.widgetWithIcon(IconButton, Icons.delete_outline);
    // The last delete icon should be the one in the taper plan row
    // (presets and thresholds sections come first and are empty).
    await tester.tap(deleteIcons.last);
    await tester.pump();
    await pumpAndWait(tester);

    // The plan should be gone.
    expect(find.text('No taper plans yet'), findsOneWidget);

    // Verify it was deleted from the database.
    final plans = await db.select(db.taperPlans).get();
    expect(plans, isEmpty);

    await cleanUp(tester);
  });
}
