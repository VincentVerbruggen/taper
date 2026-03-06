import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/dashboard/trackable_log_screen.dart';
import 'package:taper/screens/log/add_dose_screen.dart';
import 'package:taper/screens/log/edit_dose_screen.dart';

import 'helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late Trackable caffeine;
  late SharedPreferences prefs;
  final fixedNow = DateTime(2026, 2, 23, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = createTestDatabase();
    final trackables = await db.select(db.trackables).get();
    caffeine = trackables.firstWhere((s) => s.name == 'Caffeine');
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
        nowProvider.overrideWithValue(() => fixedNow),
      ],
      child: MaterialApp(home: TrackableLogScreen(trackable: caffeine)),
    );
  }

  Future<void> cleanUp(WidgetTester tester, {bool hasNavigated = false}) async {
    if (hasNavigated) {
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await db.close();
    await tester.pump();
  }

  testWidgets('shows trackable name and day subtitle', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Caffeine'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);

    await cleanUp(tester);
  });

  testWidgets('shows empty state when selected day has no doses', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('No doses logged on this day.'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows decay graph for selected day', (tester) async {
    await db.insertDoseLog(caffeine.id, 90, DateTime(2026, 2, 23, 9));

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('previous day navigation switches the one-day list', (
    tester,
  ) async {
    await db.insertDoseLog(caffeine.id, 90, DateTime(2026, 2, 23, 9));
    await db.insertDoseLog(caffeine.id, 60, DateTime(2026, 2, 22, 9));

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Today by default.
    expect(find.textContaining('90 mg'), findsNWidgets(2));
    expect(find.textContaining('60 mg'), findsNothing);

    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();

    expect(find.text('Yesterday'), findsWidgets);
    expect(find.textContaining('90 mg'), findsNothing);
    expect(find.textContaining('60 mg'), findsNWidgets(2));

    await cleanUp(tester);
  });

  testWidgets('planned dose is labeled in list subtitle', (tester) async {
    await db.insertDoseLog(
      caffeine.id,
      80,
      DateTime(2026, 2, 23, 10),
      isPlanned: true,
    );

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.textContaining('Planned'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('copy dose keeps original date but uses current time', (
    tester,
  ) async {
    final originalLoggedAt = DateTime(2026, 2, 22, 9, 15);
    await db.insertDoseLog(
      caffeine.id,
      65,
      originalLoggedAt,
      name: 'Afternoon',
      isPlanned: true,
    );

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pumpAndSettle();
    expect(find.byType(AddDoseScreen), findsOneWidget);

    // Save directly to verify the pre-filled date/time behavior.
    await tester.tap(find.byTooltip('Log Dose'));
    await tester.pumpAndSettle();

    final logs = await db.select(db.doseLogs).get();
    expect(logs, hasLength(2));
    logs.sort((a, b) => a.id.compareTo(b.id));

    final original = logs.first;
    final copied = logs.last;
    expect(copied.trackableId, original.trackableId);
    expect(copied.amount, original.amount);
    expect(copied.name, original.name);
    expect(copied.isPlanned, original.isPlanned);
    expect(copied.loggedAt, DateTime(2026, 2, 22, 12, 0));

    await cleanUp(tester);
  });

  testWidgets('tapping a dose navigates to EditDoseScreen', (tester) async {
    await db.insertDoseLog(caffeine.id, 75, DateTime(2026, 2, 23, 10));

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(
      find.ancestor(
        of: find.textContaining('75 mg').last,
        matching: find.byType(ListTile),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EditDoseScreen), findsOneWidget);

    await cleanUp(tester, hasNavigated: true);
  });
}
