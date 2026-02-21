import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/trackables/add_trackable_screen.dart';
import 'package:taper/screens/trackables/edit_trackable_screen.dart';
import 'package:taper/screens/trackables/trackables_screen.dart';

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

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: const MaterialApp(
        home: Scaffold(body: TrackablesScreen()),
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

  // --- Header test ---

  testWidgets('shows Trackables header', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.text('Trackables'), findsOneWidget);

    await cleanUp(tester);
  });

  // --- Seeded data tests ---

  testWidgets('shows seeded trackables with decay model info', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.text('Caffeine'), findsOneWidget);
    // Caffeine has exponential decay model → shows half-life.
    expect(find.text('mg \u00B7 half-life: 5.0h'), findsOneWidget);

    expect(find.text('Water'), findsOneWidget);
    // Water has no decay model → shows just the unit.
    expect(find.text('ml'), findsAtLeast(1));

    expect(find.text('Alcohol'), findsOneWidget);
    // Alcohol has linear decay model → shows elimination rate.
    expect(find.text('ml \u00B7 elimination: 9.0 ml/h'), findsOneWidget);

    await cleanUp(tester);
  });

  // --- Add trackable via bottom sheet ---

  testWidgets('FAB navigates to AddTrackableScreen', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Tap the FAB to navigate to the add trackable screen.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Should be on the AddTrackableScreen.
    expect(find.byType(AddTrackableScreen), findsOneWidget);
    // "Add Trackable" in the AppBar title AND as the FilledButton label.
    expect(find.text('Add Trackable'), findsNWidgets(2));
    // Should have 2 text fields (name + unit) and a decay model dropdown.
    // No half-life or elimination rate fields yet (decay model starts as "None").
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('None'), findsOneWidget);

    await cleanUp(tester, hasNavigated: true);
  });

  testWidgets('add trackable with custom unit and decay model none', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Navigate to add trackable screen.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Find the text fields (name + unit).
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));

    // Enter trackable name and unit. Decay model stays as "None".
    await tester.enterText(textFields.at(0), 'Vitamin D');
    await tester.enterText(textFields.at(1), 'IU');
    await tester.pump();

    // Scroll the save button into view (may be off-screen in 600px viewport).
    await tester.ensureVisible(find.byType(FilledButton));
    // Tap the FilledButton ("Add Trackable" save button).
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await pumpAndWait(tester);

    // Verify the trackable was inserted with correct values.
    final trackables = await db.select(db.trackables).get();
    final vitD = trackables.firstWhere((s) => s.name == 'Vitamin D');
    expect(vitD.unit, 'IU');
    expect(vitD.halfLifeHours, isNull);
    expect(vitD.decayModel, 'none');
    expect(vitD.color, trackableColorPalette[3]);

    await cleanUp(tester);
  });

  // --- Add with exponential decay model ---

  testWidgets('add trackable with exponential decay model', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Navigate to add trackable screen.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Enter name and unit.
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Nicotine');
    await tester.enterText(textFields.at(1), 'mg');
    await tester.pump();

    // Select "Exponential (half-life)" from the decay model dropdown.
    // Tap the dropdown to open it.
    await tester.tap(find.text('None'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Tap the "Exponential (half-life)" option.
    await tester.tap(find.text('Exponential (half-life)').last);
    await tester.pump();

    // Half-life field should now be visible — enter a value.
    // There are now 3 text fields: name, unit, half-life.
    final updatedFields = find.byType(TextField);
    expect(updatedFields, findsNWidgets(3));
    await tester.enterText(updatedFields.at(2), '2.0');
    await tester.pump();

    // Save.
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await pumpAndWait(tester);

    // Verify the trackable was inserted with exponential decay.
    final trackables = await db.select(db.trackables).get();
    final nicotine = trackables.firstWhere((s) => s.name == 'Nicotine');
    expect(nicotine.decayModel, 'exponential');
    expect(nicotine.halfLifeHours, 2.0);
    expect(nicotine.eliminationRate, isNull);

    await cleanUp(tester);
  });

  // --- Edit trackable via three-dots menu ---

  testWidgets('three-dots menu Edit navigates to EditTrackableScreen', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Open the three-dots menu on the first trackable (Caffeine).
    // There are 3 PopupMenuButtons (one per trackable) — tap the first one.
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The popup menu should show Edit, Hide, and Delete options.
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // Tap "Edit" to navigate to the edit screen.
    await tester.tap(find.text('Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Should be on the edit screen with pre-filled fields.
    expect(find.byType(EditTrackableScreen), findsOneWidget);
    expect(find.text('Edit Trackable'), findsOneWidget);

    // TextFields: name, unit, and half-life (shown because Caffeine is exponential).
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(3));

    final nameField = tester.widget<TextField>(textFields.at(0));
    expect(nameField.controller?.text, 'Caffeine');
    final unitField = tester.widget<TextField>(textFields.at(1));
    expect(unitField.controller?.text, 'mg');
    final halfLifeField = tester.widget<TextField>(textFields.at(2));
    expect(halfLifeField.controller?.text, '5.0');

    // Decay model dropdown should show "Exponential (half-life)".
    expect(find.text('Exponential (half-life)'), findsOneWidget);

    await cleanUp(tester, hasNavigated: true);
  });

  testWidgets('edit trackable saves changes and pops back', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Open three-dots menu on Caffeine and tap Edit to navigate.
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Change unit to "g" and half-life to "6.0".
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(1), 'g');
    await tester.enterText(textFields.at(2), '6.0');
    await tester.pump();

    // Scroll the save button into view (may be off-screen in 600px viewport).
    await tester.ensureVisible(find.text('Save Changes'));
    // Tap "Save Changes".
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await pumpAndWait(tester);

    // Should be back on the trackables list.
    expect(find.byType(EditTrackableScreen), findsNothing);
    expect(find.text('Trackables'), findsOneWidget);

    // Verify the trackable was updated in the database.
    final trackables = await db.select(db.trackables).get();
    final caffeine = trackables.firstWhere((s) => s.name == 'Caffeine');
    expect(caffeine.unit, 'g');
    expect(caffeine.halfLifeHours, 6.0);

    await cleanUp(tester);
  });

  // --- Color auto-assignment ---

  testWidgets('color auto-assigned from palette', (tester) async {
    final trackables = await (db.select(db.trackables)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();

    expect(trackables[0].color, trackableColorPalette[0]);
    expect(trackables[1].color, trackableColorPalette[1]);
    expect(trackables[2].color, trackableColorPalette[2]);

    await db.insertTrackable('Test');
    final updated = await (db.select(db.trackables)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    final testTrackable = updated.firstWhere((s) => s.name == 'Test');
    expect(testTrackable.color, trackableColorPalette[3]);

    await tester.pumpWidget(const SizedBox());
    await db.close();
  });

  testWidgets('color cycles through palette for many trackables', (tester) async {
    for (var i = 0; i < 10; i++) {
      await db.insertTrackable('Sub$i');
    }

    final trackables = await (db.select(db.trackables)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();

    expect(trackables.length, 13);

    final sub7 = trackables.firstWhere((s) => s.name == 'Sub7');
    expect(sub7.color, trackableColorPalette[0]);

    await tester.pumpWidget(const SizedBox());
    await db.close();
  });

  // --- Color dot in list item ---

  testWidgets('color dot is visible in trackable list', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    final colorDots = find.byWidgetPredicate((widget) {
      if (widget is Container && widget.decoration is BoxDecoration) {
        final dec = widget.decoration as BoxDecoration;
        return dec.shape == BoxShape.circle;
      }
      return false;
    });

    expect(colorDots, findsNWidgets(3));

    await cleanUp(tester);
  });

  // --- Pin button tests ---

  testWidgets('each trackable shows a pin button', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // All 3 trackables should have an outlined pin icon (none pinned).
    expect(find.byIcon(Icons.push_pin_outlined), findsNWidgets(3));
    // No filled pin icons.
    expect(find.byIcon(Icons.push_pin), findsNothing);

    await cleanUp(tester);
  });

  testWidgets('pin icon shows filled when trackable is pinned', (tester) async {
    // Build widget, then manually pin trackable 1 via the provider.
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Pin trackable 1 (Caffeine) directly through the provider.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TrackablesScreen)),
    );
    container.read(pinnedTrackableIdProvider.notifier).pin(1);
    await tester.pump();

    // One filled pin icon (Caffeine) + two outlined (Water, Alcohol).
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_outlined), findsNWidgets(2));

    await cleanUp(tester);
  });

  // --- Drag handle tests ---

  testWidgets('each trackable shows a drag handle', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // All 3 trackables should have a drag handle icon.
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));

    await cleanUp(tester);
  });

  // --- Three-dots menu tests ---

  testWidgets('three-dots menu shows Edit, Hide, Delete', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Open the three-dots menu on the first trackable.
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // All three menu items should be visible.
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // Verify menu item icons are present.
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    // Dismiss the menu by tapping outside.
    await tester.tapAt(Offset.zero);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await cleanUp(tester);
  });

  testWidgets('three-dots menu shows "Show" for hidden trackable', (tester) async {
    // Alcohol is hidden (isVisible: false) from the seeder.
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Open the three-dots menu on Alcohol (the last / 3rd item).
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // For a hidden trackable, the menu should say "Show" instead of "Hide".
    expect(find.text('Show'), findsOneWidget);
    expect(find.byIcon(Icons.visibility), findsOneWidget);

    // Dismiss the menu.
    await tester.tapAt(Offset.zero);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await cleanUp(tester);
  });

  testWidgets('toggle visibility from menu updates the trackable', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Caffeine is visible. Open its menu and tap "Hide".
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Hide'));
    await tester.pump();
    await pumpAndWait(tester);

    // Verify in the database that Caffeine is now hidden.
    final trackables = await db.select(db.trackables).get();
    final caffeine = trackables.firstWhere((t) => t.name == 'Caffeine');
    expect(caffeine.isVisible, false);

    await cleanUp(tester);
  });

  testWidgets('delete from menu removes the trackable after confirmation', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Open the three-dots menu on the first trackable (Caffeine).
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap "Delete" to trigger the confirmation dialog.
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Confirmation dialog should be showing.
    expect(find.text('Delete Trackable'), findsOneWidget);
    expect(find.textContaining('Delete "Caffeine"?'), findsOneWidget);

    // Tap "Delete" in the dialog to confirm.
    // There are now two "Delete" texts: the dialog title uses "Delete Trackable",
    // and the confirm button says "Delete".
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pump();
    await pumpAndWait(tester);

    // Verify Caffeine was deleted from the database.
    final trackables = await db.select(db.trackables).get();
    expect(trackables.any((t) => t.name == 'Caffeine'), false);
    // Should show a snackbar.
    expect(find.text('Caffeine deleted'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('delete cancel does not remove the trackable', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Open menu and tap Delete.
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap "Cancel" in the confirmation dialog.
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await pumpAndWait(tester);

    // Caffeine should still be in the database.
    final trackables = await db.select(db.trackables).get();
    expect(trackables.any((t) => t.name == 'Caffeine'), true);

    await cleanUp(tester);
  });

  // --- No more arrow buttons ---

  testWidgets('no up/down arrow buttons in the list', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Arrow icons should no longer be present — replaced by drag handle.
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);

    await cleanUp(tester);
  });
}
