import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/settings/settings_screen.dart';
import 'package:taper/screens/trackables/add_trackable_screen.dart';
import 'package:taper/screens/trackables/edit_trackable_screen.dart';

import 'helpers/test_database.dart';

/// Trackable management tests — now rendered inside SettingsScreen
/// since the Trackables tab was merged into Settings (Milestone 8, Task 6).
void main() {
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = createTestDatabase();
  });

  tearDown(() async {
    try {
      await db.close();
    } catch (_) {}
  });

  /// Builds the test widget asynchronously so we can get the SharedPreferences
  /// instance first (needed by SettingsScreen for day boundary settings).
  Future<Widget> buildTestWidgetAsync() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(
        home: SettingsScreen(),
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

  testWidgets('shows Trackables section header', (tester) async {
    await tester.pumpWidget(await buildTestWidgetAsync());
    await pumpAndWait(tester);

    expect(find.text('Trackables'), findsOneWidget);

    await cleanUp(tester);
  });

  // --- Seeded data tests ---

  testWidgets('shows seeded trackable names', (tester) async {
    await tester.pumpWidget(await buildTestWidgetAsync());
    await pumpAndWait(tester);

    // Trackable list items show just the name (no subtitle with unit/decay info).
    expect(find.text('Caffeine'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Alcohol'), findsOneWidget);

    await cleanUp(tester);
  });

  // --- Add trackable via inline button (replaces old FAB) ---

  testWidgets('"Add trackable" button navigates to AddTrackableScreen', (tester) async {
    await tester.pumpWidget(await buildTestWidgetAsync());
    await pumpAndWait(tester);

    // Tap the "Add trackable" inline button.
    await tester.tap(find.text('Add trackable'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Should be on the AddTrackableScreen.
    expect(find.byType(AddTrackableScreen), findsOneWidget);
    // "Add Trackable" in the AppBar title AND as the FilledButton label.
    expect(find.text('Add Trackable'), findsNWidgets(2));
    // Should have 2 text fields (name + unit) and a decay model dropdown.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('None'), findsOneWidget);

    await cleanUp(tester, hasNavigated: true);
  });

  testWidgets('add trackable with custom unit and decay model none', (tester) async {
    await tester.pumpWidget(await buildTestWidgetAsync());
    await pumpAndWait(tester);

    // Navigate to add trackable screen.
    await tester.tap(find.text('Add trackable'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Find the text fields (name + unit).
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));

    // Enter trackable name and unit. Decay model stays as "None".
    await tester.enterText(textFields.at(0), 'Vitamin D');
    await tester.enterText(textFields.at(1), 'IU');
    await tester.pump();

    // Scroll the save button into view.
    await tester.ensureVisible(find.byType(FilledButton));
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
    await tester.pumpWidget(await buildTestWidgetAsync());
    await pumpAndWait(tester);

    // Navigate to add trackable screen.
    await tester.tap(find.text('Add trackable'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Enter name and unit.
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Nicotine');
    await tester.enterText(textFields.at(1), 'mg');
    await tester.pump();

    // Select "Exponential (half-life)" from the decay model dropdown.
    await tester.tap(find.text('None'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Exponential (half-life)').last);
    await tester.pump();

    // Half-life + absorption fields should now be visible (name, unit, half-life, absorption).
    final updatedFields = find.byType(TextField);
    expect(updatedFields, findsNWidgets(4));
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

  // --- Edit trackable via tap ---

  testWidgets('tapping trackable navigates to EditTrackableScreen', (tester) async {
    await tester.pumpWidget(await buildTestWidgetAsync());
    await pumpAndWait(tester);

    // Tap the Caffeine card to navigate to the edit screen.
    await tester.tap(find.text('Caffeine'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Should be on the edit screen with pre-filled fields.
    expect(find.byType(EditTrackableScreen), findsOneWidget);
    expect(find.text('Edit Trackable'), findsOneWidget);

    // TextFields: name, unit, half-life, and absorption (shown because Caffeine is exponential).
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(4));

    final nameField = tester.widget<TextField>(textFields.at(0));
    expect(nameField.controller?.text, 'Caffeine');
    final unitField = tester.widget<TextField>(textFields.at(1));
    expect(unitField.controller?.text, 'mg');
    final halfLifeField = tester.widget<TextField>(textFields.at(2));
    expect(halfLifeField.controller?.text, '5.0');

    expect(find.text('Exponential (half-life)'), findsOneWidget);

    await cleanUp(tester, hasNavigated: true);
  });

  testWidgets('edit trackable saves changes and pops back', (tester) async {
    await tester.pumpWidget(await buildTestWidgetAsync());
    await pumpAndWait(tester);

    // Tap Caffeine card to navigate to edit screen.
    await tester.tap(find.text('Caffeine'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Change unit to "g" and half-life to "6.0".
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(1), 'g');
    await tester.enterText(textFields.at(2), '6.0');
    await tester.pump();

    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await pumpAndWait(tester);

    // Should be back on the settings screen.
    expect(find.byType(EditTrackableScreen), findsNothing);
    expect(find.text('Settings'), findsOneWidget);

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
    await tester.pumpWidget(await buildTestWidgetAsync());
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
    await tester.pumpWidget(await buildTestWidgetAsync());
    await pumpAndWait(tester);

    // All 3 trackables should have an outlined pin icon (none pinned).
    expect(find.byIcon(Icons.push_pin_outlined), findsNWidgets(3));
    // No filled pin icons.
    expect(find.byIcon(Icons.push_pin), findsNothing);

    await cleanUp(tester);
  });

  testWidgets('pin icon shows filled when trackable is pinned', (tester) async {
    await tester.pumpWidget(await buildTestWidgetAsync());
    await pumpAndWait(tester);

    // Pin trackable 1 (Caffeine) directly through the provider.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
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
    await tester.pumpWidget(await buildTestWidgetAsync());
    await pumpAndWait(tester);

    // All 3 trackables should have a drag handle icon.
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));

    await cleanUp(tester);
  });

  // --- No three-dots menu (actions moved to edit screen) ---

  testWidgets('no three-dots menu on trackable list items', (tester) async {
    await tester.pumpWidget(await buildTestWidgetAsync());
    await pumpAndWait(tester);

    // The three-dots menu icon should not be present — all management
    // actions (duplicate, hide/show, delete) are now in the edit screen.
    expect(find.byIcon(Icons.more_vert), findsNothing);

    await cleanUp(tester);
  });

  // --- No more arrow buttons ---

  testWidgets('no up/down arrow buttons in the list', (tester) async {
    await tester.pumpWidget(await buildTestWidgetAsync());
    await pumpAndWait(tester);

    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);

    await cleanUp(tester);
  });
}
