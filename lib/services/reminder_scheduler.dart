import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'package:taper/data/database.dart';
import 'package:taper/data/reminder_type.dart';
import 'package:taper/services/notification_service.dart';

/// Singleton service that schedules/cancels reminder notifications.
///
/// Handles two types of reminders:
///   - Scheduled: fire at a specific time (daily recurring or one-time),
///     with optional nag notifications at intervals until a dose is logged.
///   - Logging gap: fire when no dose has been logged for [gapMinutes]
///     within a daily window.
///
/// Uses flutter_local_notifications' zonedSchedule() for time-based scheduling.
/// Like a cron scheduler that manages per-reminder notification slots.
///
/// Notification ID scheme:
///   - Existing tracking notification: ID 42 (unchanged, managed by NotificationService)
///   - Reminders: 10000 + reminder.id * 100 + offset
///     - offset 0 = main scheduled notification
///     - offset 1–8 = nag notifications (pre-scheduled at intervals)
///     - offset 50 = gap notification
class ReminderScheduler {
  // --- Singleton pattern ---
  static final instance = ReminderScheduler._();
  ReminderScheduler._();

  /// The notification plugin, shared with NotificationService.
  /// Set during init() — must be called after NotificationService.init().
  FlutterLocalNotificationsPlugin? _plugin;

  /// Whether timezone data has been initialized.
  bool _tzInitialized = false;

  /// Initialize the scheduler with the notification plugin.
  /// Must be called after NotificationService.init() so the plugin is ready.
  /// Also initializes timezone data required by zonedSchedule().
  void init(FlutterLocalNotificationsPlugin plugin) {
    _plugin = plugin;
    if (!_tzInitialized) {
      // Load timezone database — required by flutter_local_notifications'
      // zonedSchedule() to convert local times to TZDateTime.
      // initializeTimeZones() loads all tz data (~1MB, runs once).
      tz_data.initializeTimeZones();
      _tzInitialized = true;
    }
  }

  /// Calculate the notification ID for a reminder.
  ///
  /// Each reminder gets a block of 100 IDs starting at 10000 + (id * 100).
  /// This gives room for the main notification (offset 0), up to 8 nag
  /// notifications (offsets 1–8), and a gap notification (offset 50).
  /// Like allocating a port range per service: reminder #1 → IDs 10100–10199.
  int _notificationId(int reminderId, {int offset = 0}) {
    return 10000 + reminderId * 100 + offset;
  }

  /// Schedule all notifications for a single reminder.
  ///
  /// Branches on type (scheduled vs logging_gap) to determine what to schedule.
  /// Only schedules if the reminder is enabled. Cancels any existing
  /// notifications for this reminder first to avoid duplicates.
  ///
  /// [trackable] is needed for the notification title (shows trackable name).
  Future<void> scheduleReminder(Reminder reminder, Trackable trackable) async {
    final plugin = _plugin;
    if (plugin == null || !reminder.isEnabled) return;

    // Always cancel existing notifications first to avoid duplicates.
    // This makes schedule idempotent — call it as many times as you want.
    await cancelReminder(reminder.id);

    final type = ReminderType.fromString(reminder.type);

    switch (type) {
      case ReminderType.scheduled:
        await _scheduleScheduledReminder(plugin, reminder, trackable);
      case ReminderType.loggingGap:
        // Gap reminders are rescheduled dynamically when doses are logged.
        // On app start, we schedule the initial gap notification based on
        // the window start + gap duration.
        await _scheduleGapReminder(plugin, reminder, trackable, null);
    }
  }

  /// Schedule a "scheduled" type reminder (daily recurring or one-time).
  ///
  /// Uses zonedSchedule() with DateTimeComponents.time for daily repeat,
  /// or a specific date for one-time reminders.
  /// Also pre-schedules nag notifications if enabled.
  Future<void> _scheduleScheduledReminder(
    FlutterLocalNotificationsPlugin plugin,
    Reminder reminder,
    Trackable trackable,
  ) async {
    if (reminder.scheduledTime == null) return;

    // Parse "HH:MM" into hour and minute.
    final parts = reminder.scheduledTime!.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    final now = tz.TZDateTime.now(tz.local);

    if (reminder.isRecurring) {
      // Daily recurring: schedule for today at the specified time.
      // If that time has already passed today, zonedSchedule with
      // DateTimeComponents.time will automatically schedule for tomorrow.
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      // If the time has passed today, schedule for tomorrow.
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await plugin.zonedSchedule(
        _notificationId(reminder.id),
        '${trackable.name} — ${reminder.label}',
        'Time for your ${reminder.label.toLowerCase()}',
        scheduledDate,
        _reminderNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // DateTimeComponents.time = daily repeat at the same time.
        // Like a daily cron: 0 8 * * * (every day at 8:00).
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } else {
      // One-time: schedule for a specific date.
      if (reminder.oneTimeDate == null) return;
      final date = reminder.oneTimeDate!;
      final scheduledDate = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );

      // Don't schedule if the date has already passed.
      if (scheduledDate.isBefore(now)) return;

      await plugin.zonedSchedule(
        _notificationId(reminder.id),
        '${trackable.name} — ${reminder.label}',
        'Time for your ${reminder.label.toLowerCase()}',
        scheduledDate,
        _reminderNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }

    // Pre-schedule nag notifications if enabled.
    // We schedule up to 8 nag slots at nagIntervalMinutes apart.
    // These get cancelled when a dose is logged (via cancelNagNotifications).
    if (reminder.nagEnabled && reminder.nagIntervalMinutes != null) {
      await _scheduleNagNotifications(plugin, reminder, trackable);
    }
  }

  /// Pre-schedule nag notifications at intervals after the main reminder.
  ///
  /// Schedules up to 8 notifications (offsets 1–8) at nagIntervalMinutes apart.
  /// Covers up to ~2 hours of nagging at 15-min intervals.
  /// These are cancelled in bulk when a dose is logged.
  Future<void> _scheduleNagNotifications(
    FlutterLocalNotificationsPlugin plugin,
    Reminder reminder,
    Trackable trackable,
  ) async {
    if (reminder.scheduledTime == null || reminder.nagIntervalMinutes == null) return;

    final parts = reminder.scheduledTime!.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    final now = tz.TZDateTime.now(tz.local);
    final interval = reminder.nagIntervalMinutes!;

    // Schedule up to 8 nag notifications.
    for (var i = 1; i <= 8; i++) {
      final nagMinutes = interval * i;

      var nagTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      ).add(Duration(minutes: nagMinutes));

      // If this nag time has passed today, schedule for tomorrow.
      if (nagTime.isBefore(now)) {
        nagTime = nagTime.add(const Duration(days: 1));
      }

      await plugin.zonedSchedule(
        _notificationId(reminder.id, offset: i),
        '${trackable.name} — ${reminder.label}',
        'Reminder: ${reminder.label.toLowerCase()} (${i * interval} min ago)',
        nagTime,
        _reminderNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Daily repeat for nags too — they fire every day until cancelled.
        matchDateTimeComponents: reminder.isRecurring
            ? DateTimeComponents.time
            : null,
      );
    }
  }

  /// Schedule a logging gap reminder.
  ///
  /// Fires at [lastDoseTime + gapMinutes] if inside the window.
  /// If no dose today and inside the window, fires at [windowStart + gapMinutes].
  /// If outside the window, schedules for tomorrow's [windowStart + gapMinutes].
  ///
  /// [lastDoseTime] = when the most recent dose was logged. null = no dose today.
  Future<void> _scheduleGapReminder(
    FlutterLocalNotificationsPlugin plugin,
    Reminder reminder,
    Trackable trackable,
    DateTime? lastDoseTime,
  ) async {
    if (reminder.windowStart == null ||
        reminder.windowEnd == null ||
        reminder.gapMinutes == null) {
      return;
    }

    // Parse window start/end times.
    final startParts = reminder.windowStart!.split(':');
    final endParts = reminder.windowEnd!.split(':');
    if (startParts.length != 2 || endParts.length != 2) {
      return;
    }
    final startHour = int.tryParse(startParts[0]);
    final startMinute = int.tryParse(startParts[1]);
    final endHour = int.tryParse(endParts[0]);
    final endMinute = int.tryParse(endParts[1]);
    if (startHour == null || startMinute == null ||
        endHour == null || endMinute == null) {
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    final gap = Duration(minutes: reminder.gapMinutes!);

    // Calculate today's window boundaries.
    final windowStartToday = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, startHour, startMinute,
    );
    final windowEndToday = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, endHour, endMinute,
    );

    tz.TZDateTime fireTime;

    if (lastDoseTime != null) {
      // Schedule at lastDose + gap.
      final lastDoseTz = tz.TZDateTime.from(lastDoseTime, tz.local);
      fireTime = lastDoseTz.add(gap);
    } else {
      // No dose today — fire at windowStart + gap.
      fireTime = windowStartToday.add(gap);
    }

    // Clamp fire time to within the window.
    if (fireTime.isAfter(windowEndToday)) {
      // Past today's window — schedule for tomorrow.
      final windowStartTomorrow = windowStartToday.add(const Duration(days: 1));
      fireTime = windowStartTomorrow.add(gap);
    } else if (fireTime.isBefore(now)) {
      // Fire time already passed — if still in window, fire soon.
      if (now.isBefore(windowEndToday)) {
        // We're in the window but the fire time already passed.
        // Schedule 1 minute from now as a catch-up.
        fireTime = now.add(const Duration(minutes: 1));
      } else {
        // Outside the window — schedule for tomorrow.
        final windowStartTomorrow = windowStartToday.add(const Duration(days: 1));
        fireTime = windowStartTomorrow.add(gap);
      }
    }

    await plugin.zonedSchedule(
      _notificationId(reminder.id, offset: 50),
      '${trackable.name} — ${reminder.label}',
      'No ${trackable.name.toLowerCase()} logged in ${reminder.gapMinutes} min',
      fireTime,
      _reminderNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Cancel ALL notifications for a reminder (main + nags + gap).
  /// Called when a reminder is disabled, deleted, or before rescheduling.
  Future<void> cancelReminder(int reminderId) async {
    final plugin = _plugin;
    if (plugin == null) return;

    // Cancel main notification (offset 0).
    await plugin.cancel(_notificationId(reminderId));
    // Cancel nag slots (offsets 1–8).
    for (var i = 1; i <= 8; i++) {
      await plugin.cancel(_notificationId(reminderId, offset: i));
    }
    // Cancel gap notification (offset 50).
    await plugin.cancel(_notificationId(reminderId, offset: 50));
  }

  /// Cancel only nag notifications for a reminder.
  /// Called when a dose is logged — the main reminder stays, but nags stop.
  Future<void> cancelNagNotifications(int reminderId) async {
    final plugin = _plugin;
    if (plugin == null) return;

    for (var i = 1; i <= 8; i++) {
      await plugin.cancel(_notificationId(reminderId, offset: i));
    }
  }

  /// Reschedule a gap reminder based on a new last dose time.
  /// Called when a dose is logged — pushes the gap notification forward.
  Future<void> rescheduleGapReminder(
    Reminder reminder,
    Trackable trackable,
    DateTime lastDoseTime,
  ) async {
    final plugin = _plugin;
    if (plugin == null || !reminder.isEnabled) return;
    if (ReminderType.fromString(reminder.type) != ReminderType.loggingGap) return;

    // Cancel existing gap notification before scheduling a new one.
    await plugin.cancel(_notificationId(reminder.id, offset: 50));
    await _scheduleGapReminder(plugin, reminder, trackable, lastDoseTime);
  }

  /// Schedule all enabled reminders. Called on app start.
  ///
  /// Queries all enabled reminders and their trackables, then schedules each.
  /// Like a boot() method that loads all cron jobs from the database.
  Future<void> scheduleAllReminders(AppDatabase db) async {
    final enabledReminders = await db.getAllEnabledReminders();

    for (final reminder in enabledReminders) {
      final trackable = await db.getTrackable(reminder.trackableId);
      if (trackable != null) {
        await scheduleReminder(reminder, trackable);
      }
    }
  }

  /// Hook called when a dose is logged.
  ///
  /// For the logged trackable:
  ///   - Cancels nag notifications (user responded to the reminder)
  ///   - Reschedules gap reminders (pushes the gap timer forward)
  ///
  /// Called from insertDoseLog() in database.dart so ALL dose logging paths
  /// (quick-add, add screen, notification repeat, undo restore) trigger this.
  Future<void> onDoseLogged(
    AppDatabase db,
    int trackableId,
    DateTime loggedAt,
  ) async {
    final trackableReminders = await db.getReminders(trackableId);
    final trackable = await db.getTrackable(trackableId);
    if (trackable == null) return;

    for (final reminder in trackableReminders) {
      if (!reminder.isEnabled) continue;

      final type = ReminderType.fromString(reminder.type);

      if (type == ReminderType.scheduled && reminder.nagEnabled) {
        // Cancel nag notifications — user logged a dose, stop nagging.
        await cancelNagNotifications(reminder.id);
      }

      if (type == ReminderType.loggingGap) {
        // Reschedule gap reminder — push the gap timer forward from this dose.
        await rescheduleGapReminder(reminder, trackable, loggedAt);
      }
    }
  }

  /// Build notification details for reminder notifications.
  ///
  /// Uses the reminders channel (high importance = heads-up banner).
  /// Unlike the tracking notification which is low-importance and silent,
  /// reminders are user-requested alarms that should be prominent.
  NotificationDetails _reminderNotificationDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        NotificationService.remindersChannelId,
        'Reminders',
        channelDescription: 'Scheduled reminders and logging gap alerts',
        // High importance = heads-up banner notification.
        // These are user-requested alarms, not silent tickers.
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
  }
}
