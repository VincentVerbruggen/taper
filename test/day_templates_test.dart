import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/dashboard/trackable_log_screen.dart';

import 'helpers/test_database.dart';

/// Tests for day templates — save a day's entries under a name, apply later.
///
/// Seeded test DB (see database.dart onCreate):
///   id 1 = Caffeine, id 2 = Water, id 3 = Alcohol
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late Trackable caffeine;
  final fixedNow = DateTime(2026, 2, 23, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = createTestDatabase();
    caffeine = (await db.select(db.trackables).get()).firstWhere(
      (t) => t.name == 'Caffeine',
    );
  });

  tearDown(() async {
    try {
      await db.close();
    } catch (_) {}
  });

  /// Hand-built DoseLog for saveDayTemplate(). Building the object directly
  /// (instead of insertDoseLog + read back) avoids the reminder scheduler's
  /// background work racing db.close() at the end of the test.
  DoseLog dose(
    double amount,
    DateTime loggedAt, {
    String? name,
    bool isPlanned = false,
  }) {
    return DoseLog(
      id: 0,
      trackableId: 1,
      amount: amount,
      loggedAt: loggedAt,
      name: name,
      isPlanned: isPlanned,
    );
  }

  group('DB', () {
    test('saveDayTemplate stores HH:MM times, names and planned flags', () async {
      final id = await db.saveDayTemplate(
        trackableId: 1,
        name: 'Workday',
        doses: [
          dose(90, DateTime(2026, 2, 21, 9, 0, 30), name: 'Espresso'),
          dose(60, DateTime(2026, 2, 21, 14, 30), isPlanned: true),
        ],
      );

      final entries = await db.getDayTemplateEntries(id);
      expect(entries, hasLength(2));
      expect(entries[0].time, '09:00');
      expect(entries[0].amount, 90);
      expect(entries[0].name, 'Espresso');
      expect(entries[0].isPlanned, isFalse);
      expect(entries[1].time, '14:30');
      expect(entries[1].name, isNull);
      expect(entries[1].isPlanned, isTrue);
    });

    test('watchDayTemplates returns entry counts, sorted case-insensitively', () async {
      await db.saveDayTemplate(
        trackableId: 1,
        name: 'weekend',
        doses: [dose(90, DateTime(2026, 2, 21, 9))],
      );
      await db.saveDayTemplate(
        trackableId: 1,
        name: 'Workday',
        doses: [
          dose(90, DateTime(2026, 2, 21, 9)),
          dose(60, DateTime(2026, 2, 21, 13)),
        ],
      );
      // Another trackable's template must not show up.
      await db.saveDayTemplate(
        trackableId: 2,
        name: 'Hydration',
        doses: [dose(250, DateTime(2026, 2, 21, 9))],
      );

      // .first takes one emission and cancels the stream subscription, so no
      // live listener is left behind to block db.close().
      final templates = await db.watchDayTemplates(1).first;
      expect(templates.map((t) => t.template.name), ['weekend', 'Workday']);
      expect(templates.map((t) => t.entryCount), [1, 2]);
    });

    test('overwrite replaces the entries and keeps the template id', () async {
      final id = await db.saveDayTemplate(
        trackableId: 1,
        name: 'Workday',
        doses: [
          dose(90, DateTime(2026, 2, 21, 9)),
          dose(60, DateTime(2026, 2, 21, 13)),
        ],
      );

      final returnedId = await db.saveDayTemplate(
        trackableId: 1,
        name: 'Workday',
        doses: [dose(40, DateTime(2026, 2, 22, 7, 15))],
        overwriteTemplateId: id,
      );

      expect(returnedId, id);
      expect(await db.getDayTemplates(1), hasLength(1));
      final entries = await db.getDayTemplateEntries(id);
      expect(entries, hasLength(1));
      expect(entries.single.time, '07:15');
      expect(entries.single.amount, 40);
    });

    test('renameDayTemplate changes the name', () async {
      final id = await db.saveDayTemplate(
        trackableId: 1,
        name: 'Workday',
        doses: [dose(90, DateTime(2026, 2, 21, 9))],
      );

      await db.renameDayTemplate(id, 'Office day');

      expect((await db.getDayTemplates(1)).single.name, 'Office day');
    });

    test('deleteDayTemplate removes the template and its entries', () async {
      // With FK enforcement on, deleting the template before its entries
      // would fail — this proves the children-first order.
      await db.customStatement('PRAGMA foreign_keys = ON');
      final id = await db.saveDayTemplate(
        trackableId: 1,
        name: 'Workday',
        doses: [dose(90, DateTime(2026, 2, 21, 9))],
      );

      await db.deleteDayTemplate(id);

      expect(await db.getDayTemplates(1), isEmpty);
      expect(await db.getDayTemplateEntries(id), isEmpty);
    });

    test('deleteTrackable removes its templates and entries only', () async {
      final caffeineTemplate = await db.saveDayTemplate(
        trackableId: 1,
        name: 'Workday',
        doses: [dose(90, DateTime(2026, 2, 21, 9))],
      );
      final waterTemplate = await db.saveDayTemplate(
        trackableId: 2,
        name: 'Hydration',
        doses: [dose(250, DateTime(2026, 2, 21, 9))],
      );

      await db.deleteTrackable(1);

      expect(await db.getDayTemplates(1), isEmpty);
      expect(await db.getDayTemplateEntries(caffeineTemplate), isEmpty);
      // Water's template is untouched.
      expect(await db.getDayTemplates(2), hasLength(1));
      expect(await db.getDayTemplateEntries(waterTemplate), hasLength(1));
    });
  });

  group('UI', () {
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

    /// Dispose the widget tree BEFORE closing the DB — closing first would
    /// deadlock on Drift stream subscriptions that are still alive.
    Future<void> cleanUp(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await db.close();
      await tester.pump();
    }

    /// Opens the app bar overflow menu and taps [label].
    Future<void> openMenu(WidgetTester tester, String label) async {
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    /// Scopes a finder to the top-most dialog — when dialogs are stacked,
    /// both can have e.g. a "Cancel" button.
    Finder inTopDialog(Finder finder) =>
        find.descendant(of: find.byType(AlertDialog).last, matching: finder);

    /// Doses on the viewed day (Feb 23, 05:00 → Feb 24, 05:00).
    Future<List<DoseLog>> todaysDoses() => db.getDosesBetween(
      caffeine.id,
      DateTime(2026, 2, 23, 5),
      DateTime(2026, 2, 24, 5),
    );

    /// Seeds a "Workday" template directly in the DB. Saving through the UI
    /// would leave a "Saved…" snackbar on screen, and Flutter queues the next
    /// snackbar behind it — so apply tests start from DB-seeded templates.
    Future<int> seedTemplate(List<DoseLog> doses, {String name = 'Workday'}) {
      return db.saveDayTemplate(
        trackableId: caffeine.id,
        name: name,
        doses: doses,
      );
    }

    testWidgets('saves the viewed day as a template', (tester) async {
      await db.insertDoseLog(
        caffeine.id,
        90,
        DateTime(2026, 2, 23, 9),
        name: 'Espresso',
      );
      await db.insertDoseLog(
        caffeine.id,
        60,
        DateTime(2026, 2, 23, 14, 30),
        isPlanned: true,
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await openMenu(tester, 'Save day as template…');
      await tester.enterText(find.byType(TextField), 'Workday');
      await tester.tap(inTopDialog(find.text('Save')));
      await tester.pumpAndSettle();

      expect(find.text("Saved template 'Workday' (2 entries)"), findsOneWidget);

      final templates = await db.getDayTemplates(caffeine.id);
      expect(templates.single.name, 'Workday');
      final entries = await db.getDayTemplateEntries(templates.single.id);
      expect(entries.map((e) => e.time), ['09:00', '14:30']);
      expect(entries[0].name, 'Espresso');
      expect(entries.map((e) => e.isPlanned), [false, true]);

      await cleanUp(tester);
    });

    testWidgets('skipped entries are not saved', (tester) async {
      await db.insertDoseLog(caffeine.id, 90, DateTime(2026, 2, 23, 9));
      await db.insertDoseLog(caffeine.id, 0, DateTime(2026, 2, 23, 10));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await openMenu(tester, 'Save day as template…');
      await tester.enterText(find.byType(TextField), 'Workday');
      await tester.tap(inTopDialog(find.text('Save')));
      await tester.pumpAndSettle();

      expect(find.text("Saved template 'Workday' (1 entry)"), findsOneWidget);
      final templates = await db.getDayTemplates(caffeine.id);
      final entries = await db.getDayTemplateEntries(templates.single.id);
      expect(entries.single.amount, 90);

      await cleanUp(tester);
    });

    testWidgets('a day with only skipped entries has nothing to save', (
      tester,
    ) async {
      await db.insertDoseLog(caffeine.id, 0, DateTime(2026, 2, 23, 10));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await openMenu(tester, 'Save day as template…');

      expect(find.text('No entries to save.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(await db.getDayTemplates(caffeine.id), isEmpty);

      await cleanUp(tester);
    });

    testWidgets('an empty day has nothing to save', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await openMenu(tester, 'Save day as template…');

      expect(find.text('No entries to save.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await cleanUp(tester);
    });

    testWidgets('saving without a name shows Required', (tester) async {
      await db.insertDoseLog(caffeine.id, 90, DateTime(2026, 2, 23, 9));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await openMenu(tester, 'Save day as template…');
      // No error before the first save attempt.
      expect(find.text('Required'), findsNothing);

      await tester.tap(inTopDialog(find.text('Save')));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(await db.getDayTemplates(caffeine.id), isEmpty);

      await cleanUp(tester);
    });

    testWidgets('saving under an existing name (any case) overwrites it', (
      tester,
    ) async {
      final id = await seedTemplate([dose(40, DateTime(2026, 2, 22, 7))]);
      await db.insertDoseLog(caffeine.id, 90, DateTime(2026, 2, 23, 9));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await openMenu(tester, 'Save day as template…');
      await tester.enterText(find.byType(TextField), 'workday');
      await tester.tap(inTopDialog(find.text('Save')));
      await tester.pumpAndSettle();

      expect(find.text("Overwrite 'Workday'?"), findsOneWidget);
      await tester.tap(inTopDialog(find.text('Overwrite')));
      await tester.pumpAndSettle();

      // Existing casing is kept; still one template, same id, new entries.
      expect(find.text("Saved template 'Workday' (1 entry)"), findsOneWidget);
      final templates = await db.getDayTemplates(caffeine.id);
      expect(templates.single.id, id);
      final entries = await db.getDayTemplateEntries(id);
      expect(entries.single.time, '09:00');
      expect(entries.single.amount, 90);

      await cleanUp(tester);
    });

    testWidgets('applying to today keeps times, names and planned flags', (
      tester,
    ) async {
      await seedTemplate([
        dose(90, DateTime(2026, 2, 21, 9), name: 'Espresso'),
        dose(60, DateTime(2026, 2, 21, 14, 30), isPlanned: true),
      ]);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await openMenu(tester, 'Apply template…');
      expect(find.text('2 entries'), findsOneWidget);
      await tester.tap(find.text('Workday'));
      await tester.pumpAndSettle();

      final doses = await todaysDoses();
      expect(doses, hasLength(2));
      expect(doses[0].loggedAt, DateTime(2026, 2, 23, 9));
      expect(doses[0].amount, 90);
      expect(doses[0].name, 'Espresso');
      expect(doses[0].isPlanned, isFalse);
      expect(doses[1].loggedAt, DateTime(2026, 2, 23, 14, 30));
      expect(doses[1].isPlanned, isTrue);
      expect(find.text("Applied 'Workday' (2 entries)"), findsOneWidget);

      await cleanUp(tester);
    });

    testWidgets('applying to a future day marks every entry planned', (
      tester,
    ) async {
      await seedTemplate([dose(90, DateTime(2026, 2, 21, 9))]);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Move to Feb 25 — two days after the fixed "now".
      await tester.tap(find.byTooltip('Next day'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next day'));
      await tester.pumpAndSettle();

      await openMenu(tester, 'Apply template…');
      await tester.tap(find.text('Workday'));
      await tester.pumpAndSettle();

      final doses = await db.getDosesBetween(
        caffeine.id,
        DateTime(2026, 2, 25, 5),
        DateTime(2026, 2, 26, 5),
      );
      expect(doses.single.loggedAt, DateTime(2026, 2, 25, 9));
      expect(doses.single.isPlanned, isTrue);
      expect(
        find.text("Applied 'Workday' (1 entry) as planned"),
        findsOneWidget,
      );

      await cleanUp(tester);
    });

    testWidgets('an after-midnight entry lands on the next calendar date', (
      tester,
    ) async {
      await seedTemplate([dose(30, DateTime(2026, 2, 22, 2))]);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await openMenu(tester, 'Apply template…');
      await tester.tap(find.text('Workday'));
      await tester.pumpAndSettle();

      // 02:00 belongs to the night after Feb 23, i.e. Feb 24 02:00, which is
      // still inside the viewed day (Feb 23 05:00 → Feb 24 05:00).
      final doses = await todaysDoses();
      expect(doses.single.loggedAt, DateTime(2026, 2, 24, 2));
      expect(find.text('02:00'), findsOneWidget);

      await cleanUp(tester);
    });

    testWidgets('apply adds alongside existing entries and Undo removes only '
        'the applied ones', (tester) async {
      await seedTemplate([dose(90, DateTime(2026, 2, 21, 9))]);
      await db.insertDoseLog(caffeine.id, 40, DateTime(2026, 2, 23, 8));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await openMenu(tester, 'Apply template…');
      await tester.tap(find.text('Workday'));
      await tester.pumpAndSettle();

      expect(
        (await todaysDoses()).map((d) => d.amount),
        containsAll([40.0, 90.0]),
      );

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      final doses = await todaysDoses();
      expect(doses.single.amount, 40);

      await cleanUp(tester);
    });

    testWidgets('apply dialog explains how to create a first template', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await openMenu(tester, 'Apply template…');

      expect(find.textContaining('No templates yet'), findsOneWidget);

      await cleanUp(tester);
    });

    testWidgets('templates can be renamed from the apply dialog', (
      tester,
    ) async {
      await seedTemplate([dose(90, DateTime(2026, 2, 21, 9))], name: 'Weekend');
      final id = await seedTemplate([dose(90, DateTime(2026, 2, 21, 9))]);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await openMenu(tester, 'Apply template…');
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey(id)),
          matching: find.byTooltip('Template actions'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // Another template's name is rejected (case-insensitive).
      await tester.enterText(inTopDialog(find.byType(TextField)), 'weekend');
      await tester.pump();
      expect(find.text('Name already exists'), findsOneWidget);

      await tester.enterText(inTopDialog(find.byType(TextField)), 'Office day');
      await tester.tap(inTopDialog(find.text('Save')));
      await tester.pumpAndSettle();

      // The list underneath refreshes in place.
      expect(find.text('Office day'), findsOneWidget);
      expect(
        (await db.getDayTemplates(caffeine.id)).map((t) => t.name),
        ['Office day', 'Weekend'],
      );

      await cleanUp(tester);
    });

    testWidgets('templates can be deleted from the apply dialog', (
      tester,
    ) async {
      final id = await seedTemplate([dose(90, DateTime(2026, 2, 21, 9))]);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await openMenu(tester, 'Apply template…');
      await tester.tap(find.byTooltip('Template actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text("Delete 'Workday'?"), findsOneWidget);
      await tester.tap(inTopDialog(find.text('Delete')));
      await tester.pumpAndSettle();

      expect(find.textContaining('No templates yet'), findsOneWidget);
      expect(await db.getDayTemplates(caffeine.id), isEmpty);
      expect(await db.getDayTemplateEntries(id), isEmpty);

      await cleanUp(tester);
    });
  });
}
