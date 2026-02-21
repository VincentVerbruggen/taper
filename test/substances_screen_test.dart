import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/substances/substances_screen.dart';

import 'helpers/test_database.dart';

void main() {
  // Each test gets its own in-memory DB — like Laravel's RefreshDatabase.
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
  });

  // Safety net: close DB even if test fails before cleanUp().
  tearDown(() async {
    try {
      await db.close();
    } catch (_) {}
  });

  /// Build the SubstancesScreen wrapped in ProviderScope + MaterialApp.
  /// Like setting up a Livewire test component with a mocked DB.
  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SubstancesScreen()),
      ),
    );
  }

  /// Bounded pump — same pattern as log_dose_screen_test.dart.
  Future<void> pumpAndWait(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Clean up: dispose widgets first, then close DB.
  /// Same ordering as log_dose_screen_test.dart to avoid Drift deadlocks.
  Future<void> cleanUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await db.close();
    await tester.pump();
  }

  // --- Seeded data tests ---

  testWidgets('shows seeded substances with unit + half-life info', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Caffeine: unit "mg", half-life 5.0h
    expect(find.text('Caffeine'), findsOneWidget);
    expect(find.text('mg \u00B7 half-life: 5.0h'), findsOneWidget);

    // Water: unit "ml", no half-life
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('ml'), findsOneWidget);

    // Alcohol: hidden, unit "ml", half-life 4.0h
    expect(find.text('Alcohol'), findsOneWidget);
    expect(find.text('ml \u00B7 half-life: 4.0h'), findsOneWidget);

    await cleanUp(tester);
  });

  // --- Add substance with unit + half-life ---

  testWidgets('add substance with custom unit and half-life', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Tap the FAB to open the add form.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    // The form should have three text fields: name, unit, half-life.
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(3));

    // Enter substance name.
    await tester.enterText(textFields.at(0), 'Vitamin D');
    // Enter unit.
    await tester.enterText(textFields.at(1), 'IU');
    // Enter half-life.
    await tester.enterText(textFields.at(2), '24.0');
    await tester.pump();

    // Tap Save.
    await tester.tap(find.text('Save'));
    await tester.pump();
    await pumpAndWait(tester);

    // Verify the substance was inserted with correct values.
    final substances = await db.select(db.substances).get();
    final vitD = substances.firstWhere((s) => s.name == 'Vitamin D');
    expect(vitD.unit, 'IU');
    expect(vitD.halfLifeHours, 24.0);
    // Color should be auto-assigned (4th substance = palette[3]).
    expect(vitD.color, substanceColorPalette[3]);

    await cleanUp(tester);
  });

  // --- Half-life is optional ---

  testWidgets('half-life saves as null when left empty', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Tap FAB to open add form.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    final textFields = find.byType(TextField);

    // Enter only name and unit, leave half-life empty.
    await tester.enterText(textFields.at(0), 'Supplements');
    await tester.enterText(textFields.at(1), 'capsules');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();
    await pumpAndWait(tester);

    // Verify half-life is null.
    final substances = await db.select(db.substances).get();
    final suppl = substances.firstWhere((s) => s.name == 'Supplements');
    expect(suppl.halfLifeHours, isNull);
    expect(suppl.unit, 'capsules');

    await cleanUp(tester);
  });

  // --- Edit substance unit + half-life ---

  testWidgets('edit substance updates unit and half-life', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Tap Caffeine to open edit form.
    await tester.tap(find.text('Caffeine'));
    await tester.pump();

    // The edit form should be pre-filled with Caffeine's current values.
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(3));

    // Verify pre-filled values.
    final nameField = tester.widget<TextField>(textFields.at(0));
    expect(nameField.controller?.text, 'Caffeine');
    final unitField = tester.widget<TextField>(textFields.at(1));
    expect(unitField.controller?.text, 'mg');
    final halfLifeField = tester.widget<TextField>(textFields.at(2));
    expect(halfLifeField.controller?.text, '5.0');

    // Change unit to "g" and half-life to "6.0".
    await tester.enterText(textFields.at(1), 'g');
    await tester.enterText(textFields.at(2), '6.0');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();
    await pumpAndWait(tester);

    // Verify the DB was updated.
    final substances = await db.select(db.substances).get();
    final caffeine = substances.firstWhere((s) => s.name == 'Caffeine');
    expect(caffeine.unit, 'g');
    expect(caffeine.halfLifeHours, 6.0);

    await cleanUp(tester);
  });

  // --- Color auto-assignment ---

  testWidgets('color auto-assigned from palette', (tester) async {
    // Check the seeded substances have the expected palette colors.
    final substances = await (db.select(db.substances)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();

    // Caffeine = palette[0], Water = palette[1], Alcohol = palette[2].
    expect(substances[0].color, substanceColorPalette[0]);
    expect(substances[1].color, substanceColorPalette[1]);
    expect(substances[2].color, substanceColorPalette[2]);

    // Insert a 4th substance — should get palette[3].
    await db.insertSubstance('Test');
    final updated = await (db.select(db.substances)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    final testSubstance = updated.firstWhere((s) => s.name == 'Test');
    expect(testSubstance.color, substanceColorPalette[3]);

    await tester.pumpWidget(const SizedBox());
    await db.close();
  });

  testWidgets('color cycles through palette for many substances', (tester) async {
    // Insert 10 more substances (3 seeded + 10 = 13 total).
    // Colors should cycle: palette[3], [4], ..., [9], [0], [1], [2].
    for (var i = 0; i < 10; i++) {
      await db.insertSubstance('Sub$i');
    }

    final substances = await (db.select(db.substances)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();

    // 13 total: 3 seeded + 10 added.
    expect(substances.length, 13);

    // The 11th substance (index 10) wraps around: count was 10 at insert,
    // so color = palette[10 % 10] = palette[0].
    final sub7 = substances.firstWhere((s) => s.name == 'Sub7');
    // sub7 was inserted when count=10 → palette[10 % 10] = palette[0]
    expect(sub7.color, substanceColorPalette[0]);

    await tester.pumpWidget(const SizedBox());
    await db.close();
  });

  // --- Color dot in list item ---

  testWidgets('color dot is visible in substance list', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Find Container widgets with circle BoxShape — those are the color dots.
    // Each substance in the list should have one.
    final colorDots = find.byWidgetPredicate((widget) {
      if (widget is Container && widget.decoration is BoxDecoration) {
        final dec = widget.decoration as BoxDecoration;
        return dec.shape == BoxShape.circle;
      }
      return false;
    });

    // 3 seeded substances = 3 color dots.
    expect(colorDots, findsNWidgets(3));

    await cleanUp(tester);
  });
}
