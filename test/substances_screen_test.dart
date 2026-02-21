import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/substances/substances_screen.dart';

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
        home: Scaffold(body: SubstancesScreen()),
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

  // --- Header test ---

  testWidgets('shows Substances header', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.text('Substances'), findsOneWidget);

    await cleanUp(tester);
  });

  // --- Seeded data tests ---

  testWidgets('shows seeded substances with unit + half-life info', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    expect(find.text('Caffeine'), findsOneWidget);
    expect(find.text('mg \u00B7 half-life: 5.0h'), findsOneWidget);

    expect(find.text('Water'), findsOneWidget);
    expect(find.text('ml'), findsOneWidget);

    expect(find.text('Alcohol'), findsOneWidget);
    expect(find.text('ml \u00B7 half-life: 4.0h'), findsOneWidget);

    await cleanUp(tester);
  });

  // --- Add substance via bottom sheet ---

  testWidgets('FAB opens add substance bottom sheet', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Tap the FAB to open the bottom sheet.
    await tester.tap(find.byType(FloatingActionButton));
    // Extra pump time for the bottom sheet slide-up animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // "Add Substance" appears as the heading AND as the FilledButton label.
    expect(find.text('Add Substance'), findsNWidgets(2));
    // Should have 3 text fields: name, unit, half-life.
    expect(find.byType(TextField), findsNWidgets(3));

    // Close by tapping the heading.
    await tester.tap(find.text('Add Substance').first);
    await tester.pump(const Duration(milliseconds: 500));

    await cleanUp(tester);
  });

  testWidgets('add substance with custom unit and half-life', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Open add substance bottom sheet.
    await tester.tap(find.byType(FloatingActionButton));
    // Extra pump time for the bottom sheet slide-up animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Find the text fields inside the bottom sheet.
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(3));

    // Enter substance name.
    await tester.enterText(textFields.at(0), 'Vitamin D');
    // Enter unit.
    await tester.enterText(textFields.at(1), 'IU');
    // Enter half-life.
    await tester.enterText(textFields.at(2), '24.0');
    await tester.pump();

    // Scroll the save button into view (may be off-screen in 600px viewport).
    await tester.ensureVisible(find.byType(FilledButton));
    // Tap the FilledButton ("Add Substance" save button).
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await pumpAndWait(tester);

    // Verify the substance was inserted with correct values.
    final substances = await db.select(db.substances).get();
    final vitD = substances.firstWhere((s) => s.name == 'Vitamin D');
    expect(vitD.unit, 'IU');
    expect(vitD.halfLifeHours, 24.0);
    expect(vitD.color, substanceColorPalette[3]);

    await cleanUp(tester);
  });

  // --- Half-life is optional ---

  testWidgets('half-life saves as null when left empty', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await pumpAndWait(tester);

    // Open add substance bottom sheet.
    await tester.tap(find.byType(FloatingActionButton));
    // Extra pump time for the bottom sheet slide-up animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final textFields = find.byType(TextField);

    // Enter only name and unit, leave half-life empty.
    await tester.enterText(textFields.at(0), 'Supplements');
    await tester.enterText(textFields.at(1), 'capsules');
    await tester.pump();

    // Scroll the save button into view (may be off-screen in 600px viewport).
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await pumpAndWait(tester);

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

    // Tap Caffeine to open inline edit form.
    await tester.tap(find.text('Caffeine'));
    await tester.pump();

    // The edit form should be pre-filled.
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(3));

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

    final substances = await db.select(db.substances).get();
    final caffeine = substances.firstWhere((s) => s.name == 'Caffeine');
    expect(caffeine.unit, 'g');
    expect(caffeine.halfLifeHours, 6.0);

    await cleanUp(tester);
  });

  // --- Color auto-assignment ---

  testWidgets('color auto-assigned from palette', (tester) async {
    final substances = await (db.select(db.substances)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();

    expect(substances[0].color, substanceColorPalette[0]);
    expect(substances[1].color, substanceColorPalette[1]);
    expect(substances[2].color, substanceColorPalette[2]);

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
    for (var i = 0; i < 10; i++) {
      await db.insertSubstance('Sub$i');
    }

    final substances = await (db.select(db.substances)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();

    expect(substances.length, 13);

    final sub7 = substances.firstWhere((s) => s.name == 'Sub7');
    expect(sub7.color, substanceColorPalette[0]);

    await tester.pumpWidget(const SizedBox());
    await db.close();
  });

  // --- Color dot in list item ---

  testWidgets('color dot is visible in substance list', (tester) async {
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
}
