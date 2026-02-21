import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/data/database.dart';
import 'package:taper/data/decay_model.dart';
import 'package:taper/screens/shared/quick_add_dose_dialog.dart';
import 'package:taper/utils/day_boundary.dart';
import 'package:taper/utils/decay_calculator.dart';

/// Manages a persistent "party mode" notification for rapid dose logging.
///
/// Pin a trackable → an ongoing notification shows current stats (active / total)
/// with "Repeat Last" and "Add Dose" action buttons. Updated every 60 seconds.
///
/// This is a singleton — one notification at a time, managed globally.
/// Like a Laravel singleton service bound in the container:
///   $app->singleton(NotificationService::class)
///
/// The notification lives as long as the app process is alive (foreground or
/// recent apps tray). No background isolate or foreground service needed —
/// for a party evening this is plenty.
class NotificationService {
  // --- Singleton pattern ---
  // Private constructor + static instance = only one can exist.
  // Like `new static` in a PHP singleton.
  static final instance = NotificationService._();
  NotificationService._();

  /// The flutter_local_notifications plugin — talks to Android's NotificationManager.
  /// Like a facade wrapping a native API: Notification::send().
  FlutterLocalNotificationsPlugin? _plugin;

  /// Timer that refreshes the notification content every 60 seconds.
  /// Decay values change over time, so the notification needs periodic updates.
  /// Like a setInterval() in JavaScript.
  Timer? _updateTimer;

  /// The currently pinned trackable. null = not tracking.
  Trackable? _pinnedTrackable;

  /// Database reference for querying doses. Stored on startTracking().
  AppDatabase? _db;

  /// Global navigator key — used by "Add Dose" action to open the quick-add
  /// dialog even when triggered from the notification (outside the widget tree).
  /// Set by main.dart when building MaterialApp.
  /// Like Laravel's `app('router')` — a global reference to the navigation layer.
  GlobalKey<NavigatorState>? navigatorKey;

  /// Notification ID — constant since we only show one at a time.
  /// Android uses this to update an existing notification in-place.
  static const _notificationId = 42;

  /// Notification channel ID — Android groups notifications by channel.
  /// Like a "category" for notification settings in the system UI.
  ///
  /// IMPORTANT: Android caches channel settings forever once created.
  /// If you change importance/sound/vibration, you MUST use a new channel ID
  /// (or uninstall the app). Old channel = old cached settings = old behavior.
  /// Bump the suffix if you need to change channel config.
  static const _channelId = 'tracking_v2';

  /// Action IDs for the notification buttons.
  /// When the user taps a button, Android sends this string back to our handler.
  static const _actionRepeatLast = 'repeat_last';
  static const _actionAddDose = 'add_dose';

  /// Whether a trackable is currently pinned and being tracked.
  bool get isTracking => _pinnedTrackable != null;

  /// The ID of the currently pinned trackable (for UI state).
  int? get pinnedTrackableId => _pinnedTrackable?.id;

  /// Initialize the notification plugin and register the action handler.
  ///
  /// Called once at app startup (in main.dart). Sets up:
  ///   1. Android initialization settings (app icon for the notification)
  ///   2. The callback for when the user taps notification actions
  ///
  /// Like registering a service provider in Laravel's boot() method.
  Future<void> init() async {
    _plugin = FlutterLocalNotificationsPlugin();

    // Android needs an icon resource name. '@mipmap/ic_launcher' references
    // the app icon — like referencing a drawable resource in Android XML.
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // DarwinInitializationSettings = iOS/macOS settings. We don't need
    // anything special, but the plugin requires it for cross-platform init.
    const darwinSettings = DarwinInitializationSettings();

    await _plugin!.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
      // This callback fires when the user taps notification action buttons.
      // showsUserInterface=true on the actions ensures this fires in the main
      // isolate (not a background isolate), so our singleton state is available.
      // Like a route handler for notification intents.
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  /// Request POST_NOTIFICATIONS permission on Android 13+ (API 33).
  ///
  /// Android 13 changed notifications to be opt-in — apps must explicitly
  /// request permission before showing notifications. Older versions allow
  /// notifications by default.
  ///
  /// Returns true if permission was granted (or if on an older Android version).
  /// Like checking `Gate::allows('send-notifications')` in Laravel.
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;

    final androidPlugin = _plugin!
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return false;

    // requestNotificationsPermission() shows the system permission dialog.
    // Returns true if granted, false if denied, null if not applicable.
    final granted = await androidPlugin.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Pin a trackable and show the persistent tracking notification.
  ///
  /// Steps:
  ///   1. Stop any existing tracking (only one at a time)
  ///   2. Store the trackable + DB reference
  ///   3. Show the notification immediately with current stats
  ///   4. Start a 60-second timer to keep stats fresh
  ///
  /// [trackable] = the trackable to track (need its name, halfLife, unit).
  /// [db] = database for querying doses.
  Future<void> startTracking(Trackable trackable, AppDatabase db) async {
    // Stop previous tracking if any — like clearing old state before setting new.
    await stopTracking();

    _pinnedTrackable = trackable;
    _db = db;

    // Show the notification immediately (don't wait 60s for the first update).
    await _update();

    // Start periodic updates. Timer.periodic fires every [duration],
    // recalculating the decay stats and updating the notification content.
    // Like a cron job running every 15 seconds.
    //
    // Why 15s instead of 60s? Android 14+ allows swiping away "ongoing"
    // notifications — there's no dismissal callback in flutter_local_notifications.
    // By re-showing every 15s, a dismissed notification reappears quickly.
    // With onlyAlertOnce=true, re-posting doesn't buzz/vibrate — it's silent.
    // The computation is cheap (one-shot DB query + simple decay math).
    _updateTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _update(),
    );
  }

  /// Stop tracking: dismiss the notification and cancel the timer.
  ///
  /// Safe to call even if not currently tracking (no-op).
  Future<void> stopTracking() async {
    _updateTimer?.cancel();
    _updateTimer = null;
    _pinnedTrackable = null;
    _db = null;

    // cancel() removes the notification by its ID.
    // Like Notification::where('id', 42)->delete() in Laravel.
    await _plugin?.cancel(_notificationId);
  }

  /// Recalculate stats and update the notification content.
  ///
  /// Queries the DB for today's doses, runs the decay calculator, and
  /// updates the notification body with fresh numbers.
  ///
  /// Called:
  ///   - Immediately on startTracking()
  ///   - Every 60 seconds by the timer
  ///   - After a "Repeat Last" action (so the new dose shows instantly)
  Future<void> _update() async {
    final trackable = _pinnedTrackable;
    final db = _db;
    if (trackable == null || db == null) return;

    final now = DateTime.now();
    // Read the day boundary hour directly from SharedPreferences.
    // The notification service is a singleton outside the Riverpod tree,
    // so it can't use ref.watch(). SharedPreferences is already loaded.
    final prefs = await SharedPreferences.getInstance();
    final boundaryHour = prefs.getInt('dayBoundaryHour') ?? 5;
    final boundary = dayBoundary(now, boundaryHour: boundaryHour);
    final model = DecayModel.fromString(trackable.decayModel);

    // Calculate the dose query window — same logic as trackableCardDataProvider.
    // Each decay model needs a different lookback window.
    final dosesSince = switch (model) {
      DecayModel.exponential => boundary.subtract(
          Duration(hours: (trackable.halfLifeHours! * 10).ceil()),
        ),
      DecayModel.linear => boundary.subtract(const Duration(hours: 24)),
      DecayModel.none => boundary,
    };

    // One-shot queries (not streams) — we just need the current values.
    final allDoses = await db.getDosesSince(trackable.id, dosesSince);
    final lastDose = await db.getLastDose(trackable.id);

    // Filter to just today's doses for the raw total.
    final todayDoses = allDoses.where((d) => !d.loggedAt.isBefore(boundary)).toList();
    final totalToday = DecayCalculator.totalRawAmount(todayDoses);

    // Build the notification body text based on decay model.
    // 3-way switch: exponential shows active/total, linear shows active/total,
    // none shows just the total.
    String body;
    switch (model) {
      case DecayModel.exponential:
        final active = DecayCalculator.totalActiveAt(
          doses: allDoses,
          halfLifeHours: trackable.halfLifeHours!,
          queryTime: now,
        );
        body = '${active.toStringAsFixed(0)} / ${totalToday.toStringAsFixed(0)} ${trackable.unit}';
      case DecayModel.linear:
        final active = DecayCalculator.totalActiveLinearAt(
          doses: allDoses,
          eliminationRate: trackable.eliminationRate!,
          queryTime: now,
        );
        body = '${active.toStringAsFixed(0)} / ${totalToday.toStringAsFixed(0)} ${trackable.unit}';
      case DecayModel.none:
        body = '${totalToday.toStringAsFixed(0)} ${trackable.unit}';
    }

    // Append "· Last: HH:mm" if there's a recent dose.
    if (lastDose != null) {
      final h = lastDose.loggedAt.hour.toString().padLeft(2, '0');
      final m = lastDose.loggedAt.minute.toString().padLeft(2, '0');
      body += ' · Last: $h:$m';
    }

    // Show/update the notification with action buttons.
    await _showNotification(
      title: trackable.name,
      body: body,
    );
  }

  /// Show or update the persistent notification with action buttons.
  ///
  /// Key Android notification flags:
  ///   - ongoing: true → can't be swiped away (stays pinned)
  ///   - autoCancel: false → tapping doesn't dismiss it
  ///   - actions: "Repeat Last" and "Add Dose" buttons
  ///
  /// Like creating a persistent notification in Android:
  ///   NotificationCompat.Builder(this, CHANNEL_ID)
  ///       .setOngoing(true)
  ///       .addAction(...)
  Future<void> _showNotification({
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      'Trackable Tracking',
      channelDescription: 'Persistent notification for tracking a pinned trackable',
      // Importance.low = notification sits in the shade, never pops up as a
      // heads-up banner. This is what we want for a tracking ticker that
      // refreshes every 15 seconds — it should be quiet and unobtrusive.
      // Importance.high would show a popup banner every time, which is annoying.
      // Like the difference between a toast and a modal in web UI.
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      // Action buttons shown below the notification body.
      // showsUserInterface=true is CRITICAL: it routes the action through the
      // main isolate where our singleton state (_db, _pinnedTrackable) lives.
      // With showsUserInterface=false, Android uses a background isolate that
      // has no access to our in-memory state → actions silently fail.
      // The trade-off: the app briefly opens, but the action actually works.
      actions: const [
        AndroidNotificationAction(
          _actionRepeatLast,
          'Repeat Last',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          _actionAddDose,
          'Add Dose',
          showsUserInterface: true,
        ),
      ],
    );

    await _plugin?.show(
      _notificationId,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  /// Handles taps on notification action buttons.
  ///
  /// Called by the flutter_local_notifications plugin when the user taps
  /// "Repeat Last" or "Add Dose" on the notification.
  ///
  /// Like a controller method routed by the action ID:
  ///   Route::post('/notification/{action}', [NotificationController::class, 'handle'])
  void _onNotificationResponse(NotificationResponse response) {
    switch (response.actionId) {
      case _actionRepeatLast:
        _handleRepeatLast();
        break;
      case _actionAddDose:
        _handleAddDose();
        break;
    }
  }

  /// Handle the "Repeat Last" notification action.
  ///
  /// Gets the most recent dose for the pinned trackable, inserts a new dose
  /// with the same amount at the current time, then refreshes the notification.
  ///
  /// Like: $lastDose = DoseLog::latest()->first(); DoseLog::create([...same amount...])
  Future<void> _handleRepeatLast() async {
    final trackable = _pinnedTrackable;
    final db = _db;
    if (trackable == null || db == null) return;

    final lastDose = await db.getLastDose(trackable.id);
    if (lastDose == null) return;

    // Insert a new dose with the same amount, timestamped now.
    await db.insertDoseLog(
      trackable.id,
      lastDose.amount,
      DateTime.now(),
    );

    // Refresh the notification immediately so the new dose shows up.
    await _update();
  }

  /// Handle the "Add Dose" notification action.
  ///
  /// Opens the quick-add dialog using the global navigator key.
  /// The app comes to foreground (showsUserInterface=true) and shows the dialog
  /// so the user can enter a custom amount.
  ///
  /// Like opening a modal from a global event handler:
  ///   app('router')->pushRoute('/doses/quick-add')
  void _handleAddDose() {
    final trackable = _pinnedTrackable;
    final db = _db;
    final navContext = navigatorKey?.currentContext;
    if (trackable == null || db == null || navContext == null) return;

    // Show the shared quick-add dialog. When the user logs a dose,
    // it inserts via the DB and we refresh the notification.
    showQuickAddDoseDialog(
      context: navContext,
      trackable: trackable,
      db: db,
    ).then((_) {
      // Refresh notification after dialog closes (whether a dose was added or not).
      _update();
    });
  }
}
