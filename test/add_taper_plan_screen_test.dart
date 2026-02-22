import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/trackables/add_taper_plan_screen.dart';

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

  /// Build a test widget wrapping AddTaperPlanScreen.
  Widget buildTestWidget(
    Trackable trackable, {
    double? initialStartAmount,
    double? initialTargetAmount,
  }) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: AddTaperPlanScreen(
          trackable: trackable,
          initialStartAmount: initialStartAmount,
          initialTargetAmount: initialTargetAmount,
        ),
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

  Future<Trackable> getCaffeine() async {
    final trackables = await db.select(db.trackables).get();
    return trackables.firstWhere((s) => s.name == 'Caffeine');
  }

  // --- Basic rendering tests ---

  testWidgets('shows New Taper Plan title', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    expect(find.text('New Taper Plan'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows all form fields', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Amount fields with unit suffix.
    expect(find.text('Start amount'), findsOneWidget);
    expect(find.text('Target amount'), findsOneWidget);
    // Date fields.
    expect(find.text('Start date'), findsOneWidget);
    expect(find.text('End date'), findsOneWidget);
    // Create button.
    expect(find.text('Create Plan'), findsOneWidget);
    // Unit suffix should appear twice (once per amount field).
    expect(find.text('mg'), findsNWidgets(2));

    await cleanUp(tester);
  });

  // --- Validation tests ---

  testWidgets('validates empty fields on submit', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Tap Create without filling in amounts.
    await tester.tap(find.text('Create Plan'));
    await pumpAndWait(tester);

    // Both amount fields should show "Required" errors.
    expect(find.text('Required'), findsNWidgets(2));

    await cleanUp(tester);
  });

  testWidgets('validates non-numeric input', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(caffeine));
    await pumpAndWait(tester);

    // Enter just a decimal point (invalid number).
    // The input formatter only allows digits and dots, so type "0"
    // which passes the formatter but should fail the >0 check.
    final startField = find.widgetWithText(TextField, 'Start amount');
    await tester.enterText(startField, '0');
    await pumpAndWait(tester);

    // "Must be greater than zero" should show.
    expect(find.text('Must be greater than zero'), findsOneWidget);

    await cleanUp(tester);
  });

  // --- Save / creation tests ---

  testWidgets('creates plan and pops back', (tester) async {
    final caffeine = await getCaffeine();

    // Wrap in a Navigator so we can verify pop behavior.
    bool didPop = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddTaperPlanScreen(trackable: caffeine),
                    ),
                  );
                  didPop = true;
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    ));
    await pumpAndWait(tester);

    // Navigate to the form.
    await tester.tap(find.text('Open'));
    await pumpAndWait(tester);

    // Fill in valid amounts.
    final startField = find.widgetWithText(TextField, 'Start amount');
    final targetField = find.widgetWithText(TextField, 'Target amount');
    await tester.enterText(startField, '400');
    await tester.enterText(targetField, '100');
    await pumpAndWait(tester);

    // Tap Create.
    await tester.tap(find.text('Create Plan'));
    await pumpAndWait(tester);
    await tester.pump(const Duration(milliseconds: 200));

    // Should have popped back.
    expect(didPop, isTrue);

    // Verify the plan was inserted in the database.
    final plans = await (db.select(db.taperPlans)
          ..where((t) => t.trackableId.equals(caffeine.id)))
        .get();
    expect(plans.length, 1);
    expect(plans.first.startAmount, 400.0);
    expect(plans.first.targetAmount, 100.0);
    expect(plans.first.isActive, isTrue);

    await cleanUp(tester);
  });

  // --- Retry flow tests ---

  testWidgets('retry mode pre-fills amounts', (tester) async {
    final caffeine = await getCaffeine();
    await tester.pumpWidget(buildTestWidget(
      caffeine,
      initialStartAmount: 400,
      initialTargetAmount: 100,
    ));
    await pumpAndWait(tester);

    // Amount fields should be pre-filled with the old plan's values.
    final textFields = find.byType(TextField);
    final startField = tester.widget<TextField>(textFields.at(0));
    expect(startField.controller?.text, '400');
    final targetField = tester.widget<TextField>(textFields.at(1));
    expect(targetField.controller?.text, '100');

    await cleanUp(tester);
  });
}
