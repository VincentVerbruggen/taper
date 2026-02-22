import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/dashboard/widgets/taper_progress_card.dart';

import 'helpers/test_database.dart';

/// Widget tests for TaperProgressCard — the inline taper progress dashboard card.
///
/// Tests that the card:
/// - Renders plan summary and chart when an active plan exists
/// - Shows empty/fallback state when no active plan exists
/// - Tapping navigates to the full TaperProgressScreen
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
            child: TaperProgressCard(trackableId: trackableId),
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

  testWidgets('shows empty state when no active taper plan', (tester) async {
    // Caffeine has no taper plan by default.
    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    // Should show the empty state message.
    expect(find.textContaining('No active taper plan'), findsOneWidget);
    // Should show the trackable name.
    expect(find.textContaining('Caffeine'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('renders plan summary when active plan exists', (tester) async {
    // Create an active taper plan for Caffeine.
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day - 7, 5);
    final endDate = DateTime(now.year, now.month, now.day + 23, 5);
    await db.insertTaperPlan(1, 400, 100, startDate, endDate);

    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    // Should show the trackable name with "Taper" label.
    expect(find.textContaining('Caffeine'), findsOneWidget);
    expect(find.textContaining('Taper'), findsOneWidget);
    // Should show "Day X of 30" (30-day plan).
    expect(find.textContaining('Day'), findsOneWidget);
    // Should show the plan summary text with the amount range.
    // "400" may also appear in chart axis labels, so use findsWidgets.
    expect(find.textContaining('400 → 100'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('tapping navigates to full TaperProgressScreen', (tester) async {
    // Create an active taper plan.
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day - 7, 5);
    final endDate = DateTime(now.year, now.month, now.day + 23, 5);
    await db.insertTaperPlan(1, 400, 100, startDate, endDate);

    await tester.pumpWidget(buildTestWidget(trackableId: 1));
    await pumpAndWaitLong(tester);

    // Tap the card to navigate.
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Should navigate to the full TaperProgressScreen.
    // The AppBar title "Taper Progress" confirms we're on the right screen.
    expect(find.text('Taper Progress'), findsOneWidget);

    await cleanUp(tester, hasNavigated: true);
  });
}
