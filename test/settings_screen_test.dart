import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/settings/settings_screen.dart';
import 'package:taper/services/backup_service.dart';

void main() {
  setUp(() async {
    // Initialize SharedPreferences with empty values for testing.
    // Like setting up a test .env file in Laravel.
    SharedPreferences.setMockInitialValues({});
  });

  // Helper to build with a pre-loaded SharedPreferences instance.
  Future<Widget> buildTestWidgetAsync({
    Map<String, Object>? initialPrefs,
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs ?? {});
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(
        home: SettingsScreen(),
      ),
    );
  }

  testWidgets('shows Settings header', (tester) async {
    final widget = await buildTestWidgetAsync();
    await tester.pumpWidget(widget);
    await tester.pump();

    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('shows day boundary dropdown with default 05:00', (tester) async {
    final widget = await buildTestWidgetAsync();
    await tester.pumpWidget(widget);
    await tester.pump();

    // The "Day starts at" setting should be visible.
    expect(find.text('Day starts at'), findsOneWidget);
    // Default value is 5 → "05:00" shown in the dropdown.
    expect(find.text('05:00'), findsOneWidget);
  });

  testWidgets('changing dropdown persists new value', (tester) async {
    final widget = await buildTestWidgetAsync();
    await tester.pumpWidget(widget);
    await tester.pump();

    // Open the dropdown by tapping the current value.
    await tester.tap(find.text('05:00'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Select "03:00" from the dropdown menu.
    // The dropdown overlay shows all 13 items (0-12). Find "03:00" in the
    // overlay and tap it. There may be two "05:00" widgets (selected + list).
    await tester.tap(find.text('03:00').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The dropdown should now show "03:00" as selected.
    // After selection, the dropdown may still have an overlay item animating out,
    // so we check for at least one widget showing the new value.
    expect(find.text('03:00'), findsWidgets);

    // Verify the value was persisted to SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('dayBoundaryHour'), 3);
  });

  testWidgets('loads previously saved value', (tester) async {
    // Pre-set the boundary to 8 AM.
    final widget = await buildTestWidgetAsync(
      initialPrefs: {'dayBoundaryHour': 8},
    );
    await tester.pumpWidget(widget);
    await tester.pump();

    // The dropdown should show "08:00" (not the default "05:00").
    expect(find.text('08:00'), findsOneWidget);
  });

  // --- Data section: auto-backup, export, import ---

  group('Data section', () {
    testWidgets('shows Data header and all data management options',
        (tester) async {
      final widget = await buildTestWidgetAsync();
      await tester.pumpWidget(widget);
      await tester.pump();

      // Data section header.
      expect(find.text('Data'), findsOneWidget);

      // Auto-backup toggle.
      expect(find.text('Daily auto-backup'), findsOneWidget);

      // Export and import buttons.
      expect(find.text('Export database'), findsOneWidget);
      expect(find.text('Import database'), findsOneWidget);
    });

    testWidgets('auto-backup toggle defaults to enabled', (tester) async {
      final widget = await buildTestWidgetAsync();
      await tester.pumpWidget(widget);
      await tester.pump();

      // The SwitchListTile should be ON by default.
      // Find the Switch widget and check its value.
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isTrue);
    });

    testWidgets('auto-backup toggle persists when turned off', (tester) async {
      final widget = await buildTestWidgetAsync();
      await tester.pumpWidget(widget);
      await tester.pump();

      // Tap the switch to turn it off.
      // SwitchListTile's tappable area includes the whole tile.
      await tester.tap(find.text('Daily auto-backup'));
      await tester.pump();

      // Verify it's now OFF.
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);

      // Verify persistence.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(BackupService.autoBackupEnabledKey), isFalse);
    });

    testWidgets('shows "Never backed up" when no backup exists',
        (tester) async {
      final widget = await buildTestWidgetAsync();
      await tester.pumpWidget(widget);
      await tester.pump();

      expect(find.text('Never backed up'), findsOneWidget);
    });

    testWidgets('shows last backup time when a backup was recorded',
        (tester) async {
      // Set a backup time to a known value.
      final backupTime = DateTime(2026, 2, 20, 14, 30);
      final widget = await buildTestWidgetAsync(
        initialPrefs: {
          BackupService.lastBackupTimeKey:
              backupTime.millisecondsSinceEpoch,
        },
      );
      await tester.pumpWidget(widget);
      await tester.pump();

      // Should show the formatted date (not "Never backed up").
      expect(find.text('Never backed up'), findsNothing);
      // The exact format is "Feb 20, 14:30" (not today's date).
      expect(find.textContaining('Feb 20'), findsOneWidget);
    });

    testWidgets('loads auto-backup as disabled from saved prefs',
        (tester) async {
      final widget = await buildTestWidgetAsync(
        initialPrefs: {BackupService.autoBackupEnabledKey: false},
      );
      await tester.pumpWidget(widget);
      await tester.pump();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);
    });

    testWidgets('import shows confirmation dialog', (tester) async {
      final widget = await buildTestWidgetAsync();
      await tester.pumpWidget(widget);
      await tester.pump();

      // Tap "Import database".
      await tester.tap(find.text('Import database'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The confirmation dialog should appear.
      expect(find.text('Import database'), findsWidgets); // title + list tile
      expect(find.textContaining('replace ALL'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Choose file'), findsOneWidget);
    });

    testWidgets('import dialog can be cancelled', (tester) async {
      final widget = await buildTestWidgetAsync();
      await tester.pumpWidget(widget);
      await tester.pump();

      // Open import dialog.
      await tester.tap(find.text('Import database'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Cancel.
      await tester.tap(find.text('Cancel'));
      // Pump enough frames for the dialog dismiss animation to complete.
      // AlertDialog uses a ~150ms fade-out, so 300ms is plenty.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog should be dismissed — the warning text is gone.
      expect(find.textContaining('replace ALL'), findsNothing);
    });
  });
}
