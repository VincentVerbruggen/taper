import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/settings/settings_screen.dart';
import 'package:taper/services/backup_service.dart';

import 'helpers/test_database.dart';

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

  /// Helper to build the SettingsScreen with both DB and SharedPreferences.
  /// Since SettingsScreen now embeds the trackable list, it needs databaseProvider
  /// in addition to the old sharedPreferencesProvider.
  Future<Widget> buildTestWidgetAsync({
    Map<String, Object>? initialPrefs,
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs ?? {});
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

  Future<void> cleanUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await db.close();
    await tester.pump();
  }

  testWidgets('shows Settings header', (tester) async {
    final widget = await buildTestWidgetAsync();
    await tester.pumpWidget(widget);
    await pumpAndWait(tester);

    expect(find.text('Settings'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows Trackables section with seeded trackables', (tester) async {
    final widget = await buildTestWidgetAsync();
    await tester.pumpWidget(widget);
    await pumpAndWait(tester);

    // Trackables header should be visible.
    expect(find.text('Trackables'), findsOneWidget);
    // Seeded trackables should appear.
    expect(find.text('Caffeine'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Alcohol'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows "Add trackable" button', (tester) async {
    final widget = await buildTestWidgetAsync();
    await tester.pumpWidget(widget);
    await pumpAndWait(tester);

    expect(find.text('Add trackable'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('shows day boundary dropdown with default 05:00', (tester) async {
    final widget = await buildTestWidgetAsync();
    await tester.pumpWidget(widget);
    await pumpAndWait(tester);

    expect(find.text('Day starts at'), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('changing dropdown persists new value', (tester) async {
    final widget = await buildTestWidgetAsync();
    await tester.pumpWidget(widget);
    await pumpAndWait(tester);

    await tester.tap(find.text('05:00'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('03:00').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('03:00'), findsWidgets);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('dayBoundaryHour'), 3);

    await cleanUp(tester);
  });

  testWidgets('loads previously saved value', (tester) async {
    final widget = await buildTestWidgetAsync(
      initialPrefs: {'dayBoundaryHour': 8},
    );
    await tester.pumpWidget(widget);
    await pumpAndWait(tester);

    expect(find.text('08:00'), findsOneWidget);

    await cleanUp(tester);
  });

  // --- Theme mode tests ---

  testWidgets('shows theme dropdown with default Auto', (tester) async {
    final widget = await buildTestWidgetAsync();
    await tester.pumpWidget(widget);
    await pumpAndWait(tester);

    expect(find.text('Theme'), findsOneWidget);
    // Default is ThemeMode.system → shows "Auto" in the dropdown.
    expect(find.text('Auto'), findsOneWidget);

    await cleanUp(tester);
  });

  testWidgets('changing theme persists to SharedPreferences', (tester) async {
    final widget = await buildTestWidgetAsync();
    await tester.pumpWidget(widget);
    await pumpAndWait(tester);

    // Open the theme dropdown.
    await tester.tap(find.text('Auto'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Select "Dark".
    await tester.tap(find.text('Dark').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify persisted to SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('themeMode'), 'dark');

    await cleanUp(tester);
  });

  // --- Data section: auto-backup, export, import ---

  // Helper: scroll the Data section into view.
  // The trackable list at the top now pushes data management items off-screen.
  Future<void> scrollToDataSection(WidgetTester tester) async {
    // Use ensureVisible which works regardless of which Scrollable is first.
    // The outer ListView and the ReorderableListView's internal Scrollable
    // can cause find.byType(Scrollable).first to pick the wrong one.
    await tester.ensureVisible(find.text('Data'));
    await tester.pump();
  }

  group('Data section', () {
    testWidgets('shows Data header and all data management options',
        (tester) async {
      final widget = await buildTestWidgetAsync();
      await tester.pumpWidget(widget);
      await pumpAndWait(tester);

      await scrollToDataSection(tester);
      expect(find.text('Data'), findsOneWidget);

      // Scroll further to reveal all data items.
      await tester.scrollUntilVisible(
        find.text('Import database'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Daily auto-backup'), findsOneWidget);
      expect(find.text('Export database'), findsOneWidget);
      expect(find.text('Import database'), findsOneWidget);

      await cleanUp(tester);
    });

    testWidgets('auto-backup toggle defaults to enabled', (tester) async {
      final widget = await buildTestWidgetAsync();
      await tester.pumpWidget(widget);
      await pumpAndWait(tester);

      await scrollToDataSection(tester);

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isTrue);

      await cleanUp(tester);
    });

    testWidgets('auto-backup toggle persists when turned off', (tester) async {
      final widget = await buildTestWidgetAsync();
      await tester.pumpWidget(widget);
      await pumpAndWait(tester);

      // Scroll the switch into view (it's below the trackable list + theme dropdown).
      await tester.scrollUntilVisible(
        find.byType(SwitchListTile),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.text('Daily auto-backup'));
      await tester.pump();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(BackupService.autoBackupEnabledKey), isFalse);

      await cleanUp(tester);
    });

    testWidgets('shows "Never backed up" when no backup exists',
        (tester) async {
      final widget = await buildTestWidgetAsync();
      await tester.pumpWidget(widget);
      await pumpAndWait(tester);

      await scrollToDataSection(tester);

      expect(find.text('Never backed up'), findsOneWidget);

      await cleanUp(tester);
    });

    testWidgets('shows last backup time when a backup was recorded',
        (tester) async {
      final backupTime = DateTime(2026, 2, 20, 14, 30);
      final widget = await buildTestWidgetAsync(
        initialPrefs: {
          BackupService.lastBackupTimeKey:
              backupTime.millisecondsSinceEpoch,
        },
      );
      await tester.pumpWidget(widget);
      await pumpAndWait(tester);

      await scrollToDataSection(tester);

      expect(find.text('Never backed up'), findsNothing);
      expect(find.textContaining('Feb 20'), findsOneWidget);

      await cleanUp(tester);
    });

    testWidgets('loads auto-backup as disabled from saved prefs',
        (tester) async {
      final widget = await buildTestWidgetAsync(
        initialPrefs: {BackupService.autoBackupEnabledKey: false},
      );
      await tester.pumpWidget(widget);
      await pumpAndWait(tester);

      await scrollToDataSection(tester);

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);

      await cleanUp(tester);
    });

    testWidgets('import shows confirmation dialog', (tester) async {
      final widget = await buildTestWidgetAsync();
      await tester.pumpWidget(widget);
      await pumpAndWait(tester);

      // Need to scroll down to see the import button.
      await tester.scrollUntilVisible(
        find.text('Import database'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Import database'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Import database'), findsWidgets);
      expect(find.textContaining('replace ALL'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Choose file'), findsOneWidget);

      await cleanUp(tester);
    });

    testWidgets('import dialog can be cancelled', (tester) async {
      final widget = await buildTestWidgetAsync();
      await tester.pumpWidget(widget);
      await pumpAndWait(tester);

      // Scroll down to import.
      await tester.scrollUntilVisible(
        find.text('Import database'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Import database'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('replace ALL'), findsNothing);

      await cleanUp(tester);
    });
  });
}
