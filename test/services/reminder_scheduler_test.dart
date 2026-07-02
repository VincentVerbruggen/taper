import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:timezone/timezone.dart' as tz;

import 'package:taper/data/database.dart';
import 'package:taper/services/reminder_scheduler.dart';
import '../helpers/test_database.dart';

void main() {
  // ReminderScheduler touches plugin/timezone globals; initialize Flutter test
  // bindings once so plugin classes can be constructed safely in tests.
  TestWidgetsFlutterBinding.ensureInitialized();

  final scheduler = ReminderScheduler.instance;

  setUpAll(() {
    // init() wires the plugin handle and loads timezone DB once.
    scheduler.init(FlutterLocalNotificationsPlugin());
  });

  tearDown(() {
    // Reset to UTC between tests so each assertion starts from a known state.
    tz.setLocalLocation(tz.UTC);
  });

  test('configureLocalTimezone applies valid IANA timezone name', () async {
    await scheduler.configureLocalTimezone(
      timezoneNameLoader: () async => 'Europe/Amsterdam',
    );

    expect(tz.local.name, 'Europe/Amsterdam');
  });

  test(
    'configureLocalTimezone falls back when timezone name is invalid',
    () async {
      await scheduler.configureLocalTimezone(
        timezoneNameLoader: () async => 'Invalid/Timezone',
      );

      // Fallback local locations use the "DeviceOffset/+HH:MM" naming scheme.
      expect(tz.local.name, startsWith('DeviceOffset/'));
    },
  );

  test('fixedOffsetLocation builds expected offset metadata', () {
    final location = ReminderScheduler.fixedOffsetLocation(
      offset: const Duration(hours: 5, minutes: 30),
      abbreviation: 'IST',
    );

    expect(location.name, 'DeviceOffset/+05:30');
    expect(
      location.currentTimeZone.offset,
      const Duration(hours: 5, minutes: 30).inMilliseconds,
    );
    expect(location.currentTimeZone.abbreviation, 'IST');
  });

  test(
    'getLastDoseInCurrentGapWindow returns latest non-planned dose since window start',
    () async {
      final db = createTestDatabase();
      addTearDown(() async {
        try {
          await db.close();
        } catch (_) {}
      });

      // Logging-gap reminder: track inactivity during the 07:00–15:00 window.
      final reminderId = await db.insertReminder(
        trackableId: 1,
        type: 'logging_gap',
        label: 'Caffeine gap',
        windowStart: '07:00',
        windowEnd: '15:00',
        gapMinutes: 120,
      );
      final reminder = (await db.getReminders(
        1,
      )).firstWhere((r) => r.id == reminderId);

      // Before window start: should be ignored by the lookup.
      await db
          .into(db.doseLogs)
          .insert(
            DoseLogsCompanion.insert(
              trackableId: 1,
              amount: 80,
              loggedAt: DateTime(2026, 3, 6, 6, 45),
            ),
          );
      // Inside window: candidate.
      await db
          .into(db.doseLogs)
          .insert(
            DoseLogsCompanion.insert(
              trackableId: 1,
              amount: 90,
              loggedAt: DateTime(2026, 3, 6, 7, 30),
            ),
          );
      // Inside window but planned: should NOT affect reminder timing.
      await db
          .into(db.doseLogs)
          .insert(
            DoseLogsCompanion.insert(
              trackableId: 1,
              amount: 100,
              loggedAt: DateTime(2026, 3, 6, 8, 50),
              isPlanned: const Value(true),
            ),
          );
      // Latest real dose inside window: expected anchor.
      await db
          .into(db.doseLogs)
          .insert(
            DoseLogsCompanion.insert(
              trackableId: 1,
              amount: 110,
              loggedAt: DateTime(2026, 3, 6, 8, 45),
            ),
          );

      final lastDose = await scheduler.getLastDoseInCurrentGapWindow(
        reminder: reminder,
        trackableId: 1,
        db: db,
        // Fixed "now" keeps the test deterministic.
        nowProvider: () => DateTime(2026, 3, 6, 10, 0),
      );

      expect(lastDose, DateTime(2026, 3, 6, 8, 45));
    },
  );

  test(
    'getLastDoseInCurrentGapWindow returns null when no dose in window',
    () async {
      final db = createTestDatabase();
      addTearDown(() async {
        try {
          await db.close();
        } catch (_) {}
      });

      final reminderId = await db.insertReminder(
        trackableId: 1,
        type: 'logging_gap',
        label: 'Caffeine gap',
        windowStart: '07:00',
        windowEnd: '15:00',
        gapMinutes: 120,
      );
      final reminder = (await db.getReminders(
        1,
      )).firstWhere((r) => r.id == reminderId);

      // Dose exists, but it's before today's window start.
      await db
          .into(db.doseLogs)
          .insert(
            DoseLogsCompanion.insert(
              trackableId: 1,
              amount: 80,
              loggedAt: DateTime(2026, 3, 6, 6, 30),
            ),
          );

      final lastDose = await scheduler.getLastDoseInCurrentGapWindow(
        reminder: reminder,
        trackableId: 1,
        db: db,
        nowProvider: () => DateTime(2026, 3, 6, 10, 0),
      );

      expect(lastDose, isNull);
    },
  );

  test(
    'rescheduleGapReminder uses latest dose in window, not just-logged backdated dose',
    () async {
      // Scenario: User logged a dose at 10:00, then at 10:30 backdates a dose
      // to 7:00. The gap timer should anchor to 10:00 (the actual latest dose),
      // not 7:00 (the just-logged backdated dose).
      final db = createTestDatabase();
      addTearDown(() async {
        try {
          await db.close();
        } catch (_) {}
      });

      final reminderId = await db.insertReminder(
        trackableId: 1,
        type: 'logging_gap',
        label: 'Caffeine gap',
        windowStart: '07:00',
        windowEnd: '15:00',
        gapMinutes: 120,
      );
      final reminder = (await db.getReminders(
        1,
      )).firstWhere((r) => r.id == reminderId);

      // Real dose at 10:00 — the actual latest.
      await db
          .into(db.doseLogs)
          .insert(
            DoseLogsCompanion.insert(
              trackableId: 1,
              amount: 90,
              loggedAt: DateTime(2026, 3, 6, 10, 0),
            ),
          );
      // Backdated dose at 7:00 — logged later, but loggedAt is earlier.
      await db
          .into(db.doseLogs)
          .insert(
            DoseLogsCompanion.insert(
              trackableId: 1,
              amount: 80,
              loggedAt: DateTime(2026, 3, 6, 7, 0),
            ),
          );

      // The lookup should return 10:00, not 7:00.
      final lastDose = await scheduler.getLastDoseInCurrentGapWindow(
        reminder: reminder,
        trackableId: 1,
        db: db,
        nowProvider: () => DateTime(2026, 3, 6, 10, 30),
      );

      // Gap timer should anchor to 10:00 (latest in window), not 7:00 (backdated).
      expect(lastDose, DateTime(2026, 3, 6, 10, 0));
    },
  );

  test(
    'toggling planned dose to actual makes it visible to gap window lookup',
    () async {
      final db = createTestDatabase();
      addTearDown(() async {
        try {
          await db.close();
        } catch (_) {}
      });

      final reminderId = await db.insertReminder(
        trackableId: 1,
        type: 'logging_gap',
        label: 'Caffeine gap',
        windowStart: '07:00',
        windowEnd: '15:00',
        gapMinutes: 120,
      );
      final reminder = (await db.getReminders(
        1,
      )).firstWhere((r) => r.id == reminderId);

      // Insert a planned dose at 09:00.
      final doseId = await db.insertDoseLog(
        1,
        90,
        DateTime(2026, 3, 6, 9, 0),
        isPlanned: true,
      );

      // While planned, gap window should NOT see it.
      var lastDose = await scheduler.getLastDoseInCurrentGapWindow(
        reminder: reminder,
        trackableId: 1,
        db: db,
        nowProvider: () => DateTime(2026, 3, 6, 10, 0),
      );
      expect(lastDose, isNull);

      // Toggle planned → actual. We use a raw Drift update here because
      // updateDoseLog now calls onDoseLogged (the fix under test), which
      // touches the notification plugin — not available in plain unit tests.
      // This test verifies the query-level contract: once isPlanned flips to
      // false, getLastDoseInCurrentGapWindow picks up the dose.
      await (db.update(db.doseLogs)..where((t) => t.id.equals(doseId))).write(
        const DoseLogsCompanion(isPlanned: Value(false)),
      );

      // Now the gap window should see it as the latest actual dose.
      lastDose = await scheduler.getLastDoseInCurrentGapWindow(
        reminder: reminder,
        trackableId: 1,
        db: db,
        nowProvider: () => DateTime(2026, 3, 6, 10, 0),
      );
      expect(lastDose, DateTime(2026, 3, 6, 9, 0));
    },
  );
}
