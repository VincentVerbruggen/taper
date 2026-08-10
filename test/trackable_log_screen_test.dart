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

  testWidgets('day-graph x-axis labels start at the day boundary, not 00:00', (
    tester,
  ) async {
    // A dose so the chart renders (it hides itself when there are no points).
    await db.insertDoseLog(caffeine.id, 90, DateTime(2026, 2, 23, 9));

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // x = 0 is the 05:00 day boundary, so labels every 6h read as real
    // wall-clock time: 05:00 / 11:00 / 17:00 / 23:00 (05:00 repeats at x=24).
    expect(find.text('05:00'), findsWidgets);
    expect(find.text('11:00'), findsWidgets);
    // The old bug labeled the boundary point "00:00" — it must be gone now.
    expect(find.text('00:00'), findsNothing);

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

  /// Opens the app bar overflow menu and picks "Copy from another day…",
  /// then taps [dayOfMonth] in the calendar dialog that follows.
  Future<void> copyFromDay(WidgetTester tester, String dayOfMonth) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy from another day…'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(dayOfMonth));
    await tester.pumpAndSettle();
  }

  testWidgets('copies another day\'s entries into the viewed day', (
    tester,
  ) async {
    // Source day (Feb 21) — two entries at different times of day.
    await db.insertDoseLog(
      caffeine.id,
      90,
      DateTime(2026, 2, 21, 9),
      name: 'Espresso',
    );
    await db.insertDoseLog(caffeine.id, 60, DateTime(2026, 2, 21, 14, 30));

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Viewing today (Feb 23) — empty until we copy into it.
    expect(find.text('No doses logged on this day.'), findsOneWidget);

    await copyFromDay(tester, '21');

    // Times of day are preserved, only the calendar day shifts.
    final copied = await db.getDosesBetween(
      caffeine.id,
      DateTime(2026, 2, 23, 5),
      DateTime(2026, 2, 24, 5),
    );
    expect(copied, hasLength(2));
    expect(copied[0].amount, 90);
    expect(copied[0].name, 'Espresso');
    expect(copied[0].loggedAt, DateTime(2026, 2, 23, 9));
    expect(copied[0].isPlanned, isFalse);
    expect(copied[1].amount, 60);
    expect(copied[1].loggedAt, DateTime(2026, 2, 23, 14, 30));

    // Source day is untouched — this is a copy, not a move.
    final source = await db.getDosesBetween(
      caffeine.id,
      DateTime(2026, 2, 21, 5),
      DateTime(2026, 2, 22, 5),
    );
    expect(source, hasLength(2));

    expect(find.textContaining('Copied 2 entries'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('copying into a future day marks the copies as planned', (
    tester,
  ) async {
    await db.insertDoseLog(caffeine.id, 90, DateTime(2026, 2, 23, 9));

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Move to Feb 25 — two days ahead of the fixed "now".
    await tester.tap(find.byTooltip('Next day'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next day'));
    await tester.pumpAndSettle();

    await copyFromDay(tester, '23');

    final copied = await db.getDosesBetween(
      caffeine.id,
      DateTime(2026, 2, 25, 5),
      DateTime(2026, 2, 26, 5),
    );
    expect(copied, hasLength(1));
    expect(copied.first.loggedAt, DateTime(2026, 2, 25, 9));
    // Future entries are intentions, not consumed doses.
    expect(copied.first.isPlanned, isTrue);

    expect(find.textContaining('as planned'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('copies are appended to entries the day already has', (
    tester,
  ) async {
    await db.insertDoseLog(caffeine.id, 90, DateTime(2026, 2, 21, 9));
    await db.insertDoseLog(caffeine.id, 40, DateTime(2026, 2, 23, 8));

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await copyFromDay(tester, '21');

    final today = await db.getDosesBetween(
      caffeine.id,
      DateTime(2026, 2, 23, 5),
      DateTime(2026, 2, 24, 5),
    );
    expect(today, hasLength(2));
    expect(today.map((d) => d.amount), containsAll([40.0, 90.0]));

    await cleanUp(tester);
  });

  testWidgets('undo removes only the copied entries', (tester) async {
    await db.insertDoseLog(caffeine.id, 90, DateTime(2026, 2, 21, 9));
    await db.insertDoseLog(caffeine.id, 40, DateTime(2026, 2, 23, 8));

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await copyFromDay(tester, '21');

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    final today = await db.getDosesBetween(
      caffeine.id,
      DateTime(2026, 2, 23, 5),
      DateTime(2026, 2, 24, 5),
    );
    // The pre-existing 40 mg entry survives, the copy is gone.
    expect(today, hasLength(1));
    expect(today.first.amount, 40);

    await cleanUp(tester);
  });

  testWidgets('copying from an empty day reports there is nothing to copy', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await copyFromDay(tester, '21');

    expect(find.textContaining('No entries on'), findsOneWidget);

    final today = await db.getDosesBetween(
      caffeine.id,
      DateTime(2026, 2, 23, 5),
      DateTime(2026, 2, 24, 5),
    );
    expect(today, isEmpty);

    await cleanUp(tester);
  });

  testWidgets('copying a day onto itself is refused', (tester) async {
    await db.insertDoseLog(caffeine.id, 90, DateTime(2026, 2, 23, 9));

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await copyFromDay(tester, '23');

    expect(
      find.text("That's the day you're already viewing."),
      findsOneWidget,
    );

    final today = await db.getDosesBetween(
      caffeine.id,
      DateTime(2026, 2, 23, 5),
      DateTime(2026, 2, 24, 5),
    );
    expect(today, hasLength(1));

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
