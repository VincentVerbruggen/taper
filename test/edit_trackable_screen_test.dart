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

  // --- Navigation tile tests ---
  // The edit screen now shows ListTile navigation rows for Presets,
  // Thresholds, Taper Plans, and Reminders instead of inline management
  // sections. Each tile shows a count summary and a chevron_right icon.
  // Tapping a tile would push to a sub-screen (not tested here since
  // we'd need to mock Navigator or the sub-screen itself).

  testWidgets('shows Presets nav tile with "No presets" when empty', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // The Presets tile should be visible with the "No presets" subtitle.
    expect(find.text('Presets'), findsOneWidget);
    expect(find.text('No presets'), findsOneWidget);
    // Should show a chevron icon indicating navigation.
    expect(find.byIcon(Icons.chevron_right), findsWidgets);

    await cleanUp(tester);
  });

  testWidgets('Presets nav tile shows "1 preset" with one preset', (tester) async {
    final caffeine = await getCaffeine();
    // Insert one preset into the database before building the widget.
    await db.insertPreset(caffeine.id, 'Espresso', 90);
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // The tile subtitle should show the singular form.
    expect(find.text('Presets'), findsOneWidget);
    expect(find.text('1 preset'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('Presets nav tile shows "3 presets" with multiple presets', (tester) async {
    final caffeine = await getCaffeine();
    // Insert three presets.
    await db.insertPreset(caffeine.id, 'Espresso', 90);
    await db.insertPreset(caffeine.id, 'Drip Coffee', 150);
    await db.insertPreset(caffeine.id, 'Energy Drink', 200);
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // The tile subtitle should show the plural form with count.
    expect(find.text('3 presets'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows Thresholds nav tile with "No thresholds" when empty', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // The Thresholds tile should be visible with the "No thresholds" subtitle.
    expect(find.text('Thresholds'), findsOneWidget);
    expect(find.text('No thresholds'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('Thresholds nav tile shows "1 threshold" with one threshold', (tester) async {
    final caffeine = await getCaffeine();
    await db.insertThreshold(caffeine.id, 'Daily max', 400);
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    expect(find.text('Thresholds'), findsOneWidget);
    expect(find.text('1 threshold'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('Thresholds nav tile shows "2 thresholds" with multiple', (tester) async {
    final caffeine = await getCaffeine();
    await db.insertThreshold(caffeine.id, 'Daily max', 400);
    await db.insertThreshold(caffeine.id, 'Warning', 300);
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    expect(find.text('2 thresholds'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows Taper Plans nav tile with "No plans" when empty', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // The Taper Plans tile should be visible with the "No plans" subtitle.
    expect(find.text('Taper Plans'), findsOneWidget);
    expect(find.text('No plans'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('Taper Plans nav tile shows "1 active plan" with active plan', (tester) async {
    final caffeine = await getCaffeine();
    // Insert an active taper plan (isActive defaults to true).
    await db.insertTaperPlan(
      caffeine.id,
      400,
      100,
      DateTime(2026, 2, 1, 5),
      DateTime(2026, 3, 1, 5),
    );
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    expect(find.text('Taper Plans'), findsOneWidget);
    expect(find.text('1 active plan'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows Reminders nav tile with "No reminders" when empty', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // The Reminders tile should be visible with the "No reminders" subtitle.
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('No reminders'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('Reminders nav tile shows "1 reminder" with one reminder', (tester) async {
    final caffeine = await getCaffeine();
    // Insert a scheduled reminder.
    await db.insertReminder(
      trackableId: caffeine.id,
      type: 'scheduled',
      label: 'Morning dose',
      scheduledTime: '08:00',
    );
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('1 reminder'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('Reminders nav tile shows "2 reminders" with multiple', (tester) async {
    final caffeine = await getCaffeine();
    await db.insertReminder(
      trackableId: caffeine.id,
      type: 'scheduled',
      label: 'Morning dose',
      scheduledTime: '08:00',
    );
    await db.insertReminder(
      trackableId: caffeine.id,
      type: 'scheduled',
      label: 'Afternoon dose',
      scheduledTime: '14:00',
    );
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    expect(find.text('2 reminders'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('all four nav tiles are present on the edit screen', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // All four navigation tiles should be rendered.
    expect(find.text('Presets'), findsOneWidget);
    expect(find.text('Thresholds'), findsOneWidget);
    expect(find.text('Taper Plans'), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);

    // Each tile should have a chevron_right icon indicating navigation.
    // There should be 4 chevron_right icons (one per tile).
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(4));

    // Each tile should have its leading icon.
    expect(find.byIcon(Icons.bolt), findsOneWidget);
    expect(find.byIcon(Icons.horizontal_rule), findsOneWidget);
    expect(find.byIcon(Icons.trending_down), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('nav tiles show correct icons for each section', (tester) async {
    // Verify each navigation tile has its distinct leading icon.
    // This ensures the tiles are wired up with the correct visual identity
    // (like checking that sidebar icons match their labels in a web app).
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Presets tile should have the bolt icon.
    final presetsTile = find.widgetWithText(ListTile, 'Presets');
    expect(presetsTile, findsOneWidget);
    final presetsListTile = tester.widget<ListTile>(presetsTile);
    final presetsIcon = presetsListTile.leading as Icon;
    expect(presetsIcon.icon, Icons.bolt);

    // Thresholds tile should have the horizontal_rule icon.
    final thresholdsTile = find.widgetWithText(ListTile, 'Thresholds');
    final thresholdsListTile = tester.widget<ListTile>(thresholdsTile);
    final thresholdsIcon = thresholdsListTile.leading as Icon;
    expect(thresholdsIcon.icon, Icons.horizontal_rule);

    // Taper Plans tile should have the trending_down icon.
    final taperTile = find.widgetWithText(ListTile, 'Taper Plans');
    final taperListTile = tester.widget<ListTile>(taperTile);
    final taperIcon = taperListTile.leading as Icon;
    expect(taperIcon.icon, Icons.trending_down);

    // Reminders tile should have the notifications_outlined icon.
    final remindersTile = find.widgetWithText(ListTile, 'Reminders');
    final remindersListTile = tester.widget<ListTile>(remindersTile);
    final remindersIcon = remindersListTile.leading as Icon;
    expect(remindersIcon.icon, Icons.notifications_outlined);

    await cleanUp(tester);
  });
}
