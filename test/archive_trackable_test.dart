import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/settings/settings_screen.dart';

import 'helpers/test_database.dart';

/// Tests for archiving trackables — the "hide everywhere, keep data" feature.
///
/// Two layers:
///   1. DB queries: watchActiveTrackables / watchArchivedTrackables /
///      watchVisibleTrackables react to the isArchived flag correctly.
///   2. Settings UI: archived trackables move out of the main list into a
///      collapsible "Archived" section, and can be restored from there.
///
/// The seeded test DB (see database.dart onCreate) has:
///   id 1 = Caffeine (visible, not archived)
///   id 2 = Water    (visible, not archived)
///   id 3 = Alcohol  (isVisible = false, not archived)
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

  group('DB archive queries', () {
    test('active/archived/visible queries respect the isArchived flag', () async {
      // Baseline: nothing archived yet.
      expect(
        (await db.watchActiveTrackables().first).map((t) => t.name),
        containsAll(['Caffeine', 'Water', 'Alcohol']),
      );
      expect(await db.watchArchivedTrackables().first, isEmpty);
      // Visible = isVisible && !archived → Alcohol (hidden) already excluded.
      expect(
        (await db.watchVisibleTrackables().first).map((t) => t.name),
        equals(['Caffeine', 'Water']),
      );

      // Archive Caffeine (id 1).
      await db.setTrackableArchived(1, true);

      final active = (await db.watchActiveTrackables().first)
          .map((t) => t.name)
          .toList();
      final archived = (await db.watchArchivedTrackables().first)
          .map((t) => t.name)
          .toList();
      final visible = (await db.watchVisibleTrackables().first)
          .map((t) => t.name)
          .toList();

      expect(active, isNot(contains('Caffeine')));
      expect(active, containsAll(['Water', 'Alcohol']));
      expect(archived, equals(['Caffeine']));
      // Archived Caffeine drops out of the log dropdown too.
      expect(visible, equals(['Water']));
    });

    test('unarchiving restores a trackable everywhere', () async {
      await db.setTrackableArchived(1, true);
      expect(await db.watchArchivedTrackables().first, hasLength(1));

      await db.setTrackableArchived(1, false);

      expect(await db.watchArchivedTrackables().first, isEmpty);
      expect(
        (await db.watchActiveTrackables().first).map((t) => t.name),
        contains('Caffeine'),
      );
      expect(
        (await db.watchVisibleTrackables().first).map((t) => t.name),
        equals(['Caffeine', 'Water']),
      );
    });

    test('archiving keeps the trackable and its data intact', () async {
      // Log a dose so we can prove the data survives archiving.
      await db.insertDoseLog(1, 90, DateTime(2026, 2, 23, 8));

      await db.setTrackableArchived(1, true);

      // The row still exists (findable by getTrackable) and its dose is kept.
      final caffeine = await db.getTrackable(1);
      expect(caffeine, isNotNull);
      expect(caffeine!.isArchived, isTrue);
      final doses = await db.getDosesSince(1, DateTime(2026, 2, 23));
      expect(doses, hasLength(1));
    });
  });

  group('Settings archived section', () {
    Future<Widget> buildSettings() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      );
    }

    Future<void> pumpAndWait(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> cleanUp(WidgetTester tester) async {
      // Dispose the widget tree FIRST so Riverpod cancels its Drift stream
      // subscriptions, THEN close the DB. Closing while a subscription is still
      // alive deadlocks (close waits for listeners; listeners die on close).
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await db.close();
      await tester.pump();
    }

    testWidgets('archived trackable leaves the main list and appears in the '
        'Archived section', (tester) async {
      // Archive Caffeine before building the screen.
      await db.setTrackableArchived(1, true);

      await tester.pumpWidget(await buildSettings());
      await pumpAndWait(tester);

      // Caffeine is gone from the main list, and the section is collapsed, so
      // its name is nowhere on screen yet.
      expect(find.text('Caffeine'), findsNothing);
      // The collapsible Archived (1) section header is present.
      expect(find.text('Archived (1)'), findsOneWidget);
      // Active trackables still show.
      expect(find.text('Water'), findsOneWidget);

      // Expand the Archived section to reveal Caffeine.
      await tester.tap(find.text('Archived (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Caffeine'), findsOneWidget);

      await cleanUp(tester);
    });

    testWidgets('restore button unarchives the trackable', (tester) async {
      await db.setTrackableArchived(1, true);

      await tester.pumpWidget(await buildSettings());
      await pumpAndWait(tester);

      // Expand the Archived section and tap the restore (unarchive) icon.
      await tester.tap(find.text('Archived (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.unarchive_outlined));
      // _unarchive is async (DB update + reminder rescheduling queries) and
      // pops a SnackBar with a ~4s auto-dismiss timer. Pump past that whole
      // window so no async work / pending timer survives into teardown —
      // otherwise closing the DB races an in-flight Drift query and deadlocks.
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 500));

      // Caffeine is back in the active list and the Archived section is gone.
      // (Its reappearance is driven by activeTrackablesProvider re-emitting, so
      // this alone proves the unarchive propagated. The DB-level assertion lives
      // in the pure DB tests above — we avoid opening another live subscription
      // here, which would contend with the provider's stream during teardown.)
      expect(find.text('Archived (1)'), findsNothing);
      expect(find.text('Caffeine'), findsOneWidget);

      await cleanUp(tester);
    });
  });
}
