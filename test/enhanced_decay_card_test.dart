import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/dashboard/widgets/enhanced_decay_card.dart';

import 'helpers/test_database.dart';

/// Widget tests for EnhancedDecayCard — the sample12-styled decay card.
///
/// Tests that the card:
/// - Renders with trackable name and stats
/// - Chart renders (find LineChart widget)
/// - Shows Repeat Last button when doses exist
/// - Hides Repeat Last when no doses
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

  Widget buildTestWidget({int trackableId = 1}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EnhancedDecayCard(trackableId: trackableId),
          ),
        ),
      ),
    );
  }

  Future<void> pumpAndWaitLong(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> cleanUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await db.close();
    await tester.pump();
  }

  testWidgets('renders with trackable name and stats', (tester) async {
    // Insert a dose so we get stats to display.
    await db.insertDoseLog(1, 90, DateTime.now());

    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    // Should show the trackable name.
    expect(find.text('Caffeine'), findsOneWidget);
    // Stats should show "active / total unit" format with "/".
    expect(find.textContaining('/'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('chart renders with LineChart widget', (tester) async {
    // Insert a dose so the decay curve has data to render.
    await db.insertDoseLog(1, 90, DateTime.now());

    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    // The enhanced chart should render as a LineChart widget.
    expect(find.byType(LineChart), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows Repeat Last button when doses exist', (tester) async {
    await db.insertDoseLog(1, 90, DateTime.now());

    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    // "Repeat Last" should be visible when there's a previous dose.
    expect(find.text('Repeat Last'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('hides Repeat Last when no doses exist', (tester) async {
    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    // No doses → no "Repeat Last" button.
    expect(find.text('Repeat Last'), findsNothing);
    // But "Add Dose" should still be there.
    expect(find.text('Add Dose'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows Add Dose and View Log buttons', (tester) async {
    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    expect(find.text('Add Dose'), findsOneWidget);
    expect(find.text('View Log'), findsOneWidget);

    await cleanUp(tester);
  });
}
