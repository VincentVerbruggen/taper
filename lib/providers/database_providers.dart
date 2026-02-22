import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/data/decay_model.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/utils/day_boundary.dart';
import 'package:taper/utils/decay_calculator.dart';
import 'package:taper/utils/taper_calculator.dart';

/// Tracks which trackable is currently pinned to the notification.
///
/// null = no trackable pinned. Only one at a time.
/// UI watches this to show pin/unpin icon state on cards and the log screen.
///
/// Like a global $pinnedId variable in a Livewire component — any widget
/// can read it to decide whether to show a "pinned" or "unpinned" icon.
///
/// Riverpod 3.x removed StateProvider, so we use NotifierProvider instead.
/// Notifier = a class that holds mutable state, like a Vuex store module.
///
/// Reads:  ref.watch(pinnedTrackableIdProvider) → int?
/// Writes: ref.read(pinnedTrackableIdProvider.notifier).state = 42
final pinnedTrackableIdProvider =
    NotifierProvider<PinnedTrackableIdNotifier, int?>(
  PinnedTrackableIdNotifier.new,
);

/// Simple notifier that holds a nullable int (the pinned trackable's ID).
/// build() returns the initial state (null = nothing pinned).
///
/// In Riverpod 3.x, Notifier's .state setter is protected — can only be
/// accessed from inside the notifier itself. So we expose a pin()/unpin()
/// method for widgets to call. Like a Vuex mutation vs direct state access.
class PinnedTrackableIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  /// Pin a trackable (set its ID as the active pinned trackable).
  void pin(int trackableId) => state = trackableId;

  /// Unpin (clear the pinned trackable).
  void unpin() => state = null;
}

/// Generation counter that forces the databaseProvider to rebuild.
///
/// After a database import, the old Drift connection is stale (it holds a
/// file descriptor to the pre-import data). Incrementing this counter
/// invalidates databaseProvider, which creates a fresh AppDatabase() that
/// opens the newly imported file.
///
/// Like a cache-buster version number: /app.js?v=2 forces the browser
/// to re-fetch instead of using the cached copy.
///
/// All downstream providers (trackablesProvider, doseLogsProvider, etc.)
/// ref.watch(databaseProvider), so they automatically cascade-refresh.
final databaseGenerationProvider =
    NotifierProvider<DatabaseGenerationNotifier, int>(
  DatabaseGenerationNotifier.new,
);

class DatabaseGenerationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Increment to force a fresh database connection.
  /// Call this after importing a database file.
  void increment() => state++;
}

/// databaseProvider = the app's database singleton.
///
/// Like Laravel's `$app->singleton()`:
///   `$this->app->singleton(AppDatabase::class, fn() => new AppDatabase())`;
///
/// Once created, it lives forever. Every widget that needs the database
/// calls ref.read(databaseProvider) or ref.watch(databaseProvider).
///
/// Watches databaseGenerationProvider — when the generation changes (after
/// an import), this provider is invalidated and a fresh connection is opened.
final databaseProvider = Provider<AppDatabase>((ref) {
  // Watch the generation counter — when it changes after an import,
  // this provider is recreated with a fresh DB connection.
  ref.watch(databaseGenerationProvider);

  final db = AppDatabase();

  // ref.onDispose = cleanup when provider is destroyed.
  // Like __destruct() in PHP — close the DB connection.
  ref.onDispose(() => db.close());

  return db;
});

/// trackablesProvider = a reactive stream of all trackables.
///
/// Like a Livewire computed property backed by a DB query:
///   public function getTrackablesProperty() {
///       return Trackable::orderBy('name')->get();
///   }
///
/// Except it's push-based, not polling. When you insert/update/delete a trackable,
/// Drift's .watch() automatically emits the fresh list, and every widget
/// watching this provider re-renders instantly.
///
/// The AsyncValue wrapper handles three states:
///   - AsyncLoading (spinner while DB query runs first time)
///   - AsyncData (the trackable list)
///   - AsyncError (if something goes wrong)
final trackablesProvider = StreamProvider<List<Trackable>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllTrackables();
});

/// visibleTrackablesProvider = reactive stream of visible-only trackables.
///
/// Used by the Log form dropdown — hidden trackables don't appear.
/// The Trackables management screen uses trackablesProvider instead (shows ALL).
///
/// Like a Livewire computed property with a scope:
///   public function getVisibleTrackablesProperty() {
///       return Trackable::visible()->orderBy('name')->get();
///   }
final visibleTrackablesProvider = StreamProvider<List<Trackable>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchVisibleTrackables();
});

/// dashboardWidgetsProvider = reactive stream of dashboard widget configuration.
///
/// Like a Livewire computed property:
///   public function getDashboardWidgetsProperty() {
///       return DashboardWidget::orderBy('sort_order')->get();
///   }
///
/// Used by the dashboard screen to know which cards to show and in what order.
/// Decoupled from trackable visibility — a trackable can be hidden from the
/// log form dropdown but still have a widget on the dashboard.
final dashboardWidgetsProvider = StreamProvider<List<DashboardWidget>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchDashboardWidgets();
});

/// doseLogsProvider = reactive stream of recent dose logs with trackable names.
///
/// Like: DoseLog::with('trackable')->latest()->limit(50)->get()
/// ...but reactive. Used by the Log screen's recent doses list.
final doseLogsProvider = StreamProvider<List<DoseLogWithTrackable>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchRecentDoseLogs();
});

/// Reactive stream of presets for a specific trackable, keyed by trackable ID.
///
/// StreamProvider.family creates a separate provider per trackable ID — each
/// trackable's presets load independently.
///
/// Like a Livewire component with a mount($trackableId) parameter:
///   Preset::where('trackable_id', $id)->orderBy('sort_order')->get()
///
/// Used by:
///   - Edit trackable screen (manage presets list)
///   - Add dose screen (show preset chips)
final presetsProvider = StreamProvider.family<List<Preset>, int>((ref, trackableId) {
  final db = ref.watch(databaseProvider);
  return db.watchPresets(trackableId);
});

/// Reactive stream of thresholds for a specific trackable, keyed by trackable ID.
///
/// StreamProvider.family creates a separate provider per trackable ID.
/// Used by the edit trackable screen to manage thresholds.
///
/// Like: Threshold::where('trackable_id', $id)->get()
final thresholdsProvider = StreamProvider.family<List<Threshold>, int>((ref, trackableId) {
  final db = ref.watch(databaseProvider);
  return db.watchThresholds(trackableId);
});

/// Reactive stream of taper plans for a specific trackable, keyed by trackable ID.
///
/// StreamProvider.family creates a separate provider per trackable ID.
/// Used by the edit trackable screen to list all plans (active + inactive).
///
/// Like: TaperPlan::where('trackable_id', $id)->orderByDesc('start_date')->get()
final taperPlansProvider = StreamProvider.family<List<TaperPlan>, int>((ref, trackableId) {
  final db = ref.watch(databaseProvider);
  return db.watchTaperPlans(trackableId);
});

/// Reactive stream of reminders for a specific trackable, keyed by trackable ID.
///
/// StreamProvider.family creates a separate provider per trackable ID.
/// Used by the reminders screen and the edit trackable navigation tile count.
///
/// Like: Reminder::where('trackable_id', $id)->orderBy('label')->get()
final remindersProvider = StreamProvider.family<List<Reminder>, int>((ref, trackableId) {
  final db = ref.watch(databaseProvider);
  return db.watchReminders(trackableId);
});

/// Reactive stream of the active taper plan for a specific trackable.
///
/// Returns null if no active plan exists. Used by the dashboard card
/// to show today's target and the "Progress" button.
///
/// Like: TaperPlan::where('trackable_id', $id)->where('is_active', true)->first()
final activeTaperPlanProvider = StreamProvider.family<TaperPlan?, int>((ref, trackableId) {
  final db = ref.watch(databaseProvider);
  return db.watchActiveTaperPlan(trackableId);
});

/// Provides the trackable ID from the most recent dose log (across all trackables).
/// Used by the log form to auto-select the last-used trackable instead of
/// the old isMain flag. Returns null if no doses have ever been logged.
///
/// FutureProvider (one-shot, not a stream) because we only need the value
/// once when the log form opens, not reactively. Like:
///   $lastTrackableId = DoseLog::latest('logged_at')->value('trackable_id')
final lastLoggedTrackableIdProvider = FutureProvider<int?>((ref) async {
  final db = ref.watch(databaseProvider);
  final lastDose = await db.getLastDoseLogGlobal();
  return lastDose?.trackableId;
});

/// Selected date for the dashboard view.
///
/// null = today (live, real-time updates).
/// Non-null = viewing a specific past date (static snapshot at end of that day).
///
/// Like a URL parameter in a web dashboard: /dashboard?date=2026-02-19.
/// When null, the dashboard shows live data; when set, it shows historical data.
final selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, DateTime?>(
  SelectedDateNotifier.new,
);

class SelectedDateNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Set to a specific date to view that day's data.
  void selectDate(DateTime date) => state = date;

  /// Reset to live/today view.
  void goToToday() => state = null;

  /// Go to the previous day.
  void previousDay() {
    final boundaryHour = ref.read(dayBoundaryHourProvider);
    final current = state ?? dayBoundary(DateTime.now(), boundaryHour: boundaryHour);
    state = current.subtract(const Duration(days: 1));
  }

  /// Go to the next day. Snaps back to null (live) if reaching today.
  void nextDay() {
    if (state == null) return; // Already on today.
    final boundaryHour = ref.read(dayBoundaryHourProvider);
    final next = state!.add(const Duration(days: 1));
    final todayBoundary = dayBoundary(DateTime.now(), boundaryHour: boundaryHour);
    // If the next day would be today or later, go to live mode.
    if (!next.isBefore(todayBoundary)) {
      state = null;
    } else {
      state = next;
    }
  }
}

/// Data class holding everything a trackable card needs to display.
///
/// Like a Laravel Resource/DTO that bundles the model with computed values:
///   class TrackableCardResource extends JsonResource {
///       public function toArray() {
///           return ['trackable' => $this, 'activeAmount' => ..., 'curvePoints' => ...];
///       }
///   }
class TrackableCardData {
  final Trackable trackable;

  /// Decayed amount at the moment of calculation (e.g., "42 mg active").
  /// 0 for trackables without a half-life (like Water).
  final double activeAmount;

  /// Raw sum of all doses since the day boundary (e.g., "180 mg today").
  /// No decay applied — just total consumed.
  final double totalToday;

  /// Chart data: sampled every 5 minutes from day boundary to next boundary.
  /// Empty for trackables without a half-life.
  final List<({DateTime time, double amount})> curvePoints;

  /// The day boundary (5 AM) used to generate the curve.
  /// Passed to the chart so X-axis labels can show clock times.
  final DateTime dayBoundaryTime;

  /// Most recent dose for this trackable (for "Repeat Last" button).
  /// null if no doses ever logged.
  final DoseLog? lastDose;

  /// Threshold lines to draw on the chart (name + amount pairs).
  /// Each one appears as a dashed horizontal line.
  final List<Threshold> thresholds;

  /// Cumulative intake staircase data points.
  /// Goes up with each dose, never comes down — shows total consumed today.
  /// Empty when the toggle is off or decay model is "none".
  final List<({DateTime time, double amount})> cumulativePoints;

  /// Today's daily target from the active taper plan.
  /// null if no active plan exists. Shows in the stats text as "(target: X)".
  /// Like a computed property: TaperCalculator::dailyTarget($plan, today())
  final double? taperTarget;

  /// The active taper plan object itself.
  /// null if no active plan. Used for navigating to the progress screen
  /// and showing the "Progress" toolbar button.
  final TaperPlan? activeTaperPlan;

  TrackableCardData({
    required this.trackable,
    required this.activeAmount,
    required this.totalToday,
    required this.curvePoints,
    required this.dayBoundaryTime,
    required this.lastDose,
    required this.thresholds,
    required this.cumulativePoints,
    this.taperTarget,
    this.activeTaperPlan,
  });
}

/// Per-trackable card data provider, keyed by trackable ID.
///
/// StreamProvider.family creates a separate provider instance for each trackable,
/// so cards load independently (staggered). Each watches its own dose stream.
///
/// Like a Livewire component with a mount($trackableId) parameter — each card
/// is its own reactive unit with its own DB query.
///
/// The provider combines two streams (doses + lastDose) using Rx.combineLatest
/// pattern via StreamZip, then runs the decay calculator on each emission.
final trackableCardDataProvider =
    StreamProvider.family<TrackableCardData, int>((ref, trackableId) {
  final db = ref.watch(databaseProvider);
  // Watch the day boundary hour setting so cards recalculate when it changes.
  final boundaryHour = ref.watch(dayBoundaryHourProvider);
  // Watch the selected date for historical views.
  // null = today/live; non-null = viewing a past day.
  final selectedDate = ref.watch(selectedDateProvider);

  final now = DateTime.now();

  // When viewing a past date, use that date's boundary; otherwise use today.
  final boundary = selectedDate ?? dayBoundary(now, boundaryHour: boundaryHour);
  final nextBoundary = selectedDate != null
      ? DateTime(boundary.year, boundary.month, boundary.day + 1, boundaryHour)
      : nextDayBoundary(now, boundaryHour: boundaryHour);
  // For past dates, calculate active amount at the end of that day.
  // For today (live), use the current time.
  final queryTime = selectedDate != null ? nextBoundary : now;

  // First, get the trackable itself. We need its halfLifeHours to calculate
  // the decay window. Watch it reactively in case it gets edited.
  final trackablesAsync = ref.watch(trackablesProvider);

  return trackablesAsync.when(
    loading: () => const Stream.empty(),
    error: (e, s) => Stream.error(e, s),
    data: (trackables) {
      final trackable = trackables.where((t) => t.id == trackableId).firstOrNull;
      if (trackable == null) return Stream.error('Trackable not found');

      // Determine the decay model for this trackable.
      final model = DecayModel.fromString(trackable.decayModel);

      // Calculate the dose query window based on decay model:
      //   - exponential: look back 10 × halfLife hours (< 0.1% remains after that)
      //   - linear: look back 24h (conservative; doses deplete faster for small amounts)
      //   - none: just the day boundary (no decay, only count today's totals)
      final dosesSince = switch (model) {
        DecayModel.exponential => boundary.subtract(
            Duration(hours: (trackable.halfLifeHours! * 10).ceil()),
          ),
        DecayModel.linear => boundary.subtract(const Duration(hours: 24)),
        DecayModel.none => boundary,
      };

      // Watch four streams: all relevant doses, most recent dose (for Repeat Last),
      // thresholds (for horizontal chart lines), and active taper plan (for target).
      final dosesStream = db.watchDosesSince(trackableId, dosesSince);
      final lastDoseStream = db.watchLastDose(trackableId);
      final thresholdsStream = db.watchThresholds(trackableId);
      final taperPlanStream = db.watchActiveTaperPlan(trackableId);

      // Combine all four streams. When any emits, recalculate the card data.
      // Like Livewire's computed properties that depend on multiple queries —
      // when any source changes, the whole card re-renders.
      return _combineStreams(dosesStream, lastDoseStream, thresholdsStream, taperPlanStream).map((combined) {
        final allDoses = combined.$1;
        final lastDose = combined.$2;
        final thresholdsList = combined.$3;
        final activePlan = combined.$4;

        // Filter doses to just "today" (since day boundary) for the raw total.
        final todayDoses =
            allDoses.where((d) => !d.loggedAt.isBefore(boundary)).toList();

        // 3-way switch on decay model — each branch calculates active amount
        // and curve points using its own formula.
        final (double activeAmount, List<({DateTime time, double amount})> curvePoints) =
            switch (model) {
          DecayModel.exponential => (
            DecayCalculator.totalActiveAt(
              doses: allDoses,
              halfLifeHours: trackable.halfLifeHours!,
              queryTime: queryTime,
              absorptionMinutes: trackable.absorptionMinutes,
            ),
            DecayCalculator.generateCurve(
              doses: allDoses,
              halfLifeHours: trackable.halfLifeHours!,
              startTime: boundary,
              endTime: nextBoundary,
              absorptionMinutes: trackable.absorptionMinutes,
            ),
          ),
          DecayModel.linear => (
            DecayCalculator.totalActiveLinearAt(
              doses: allDoses,
              eliminationRate: trackable.eliminationRate!,
              queryTime: queryTime,
              absorptionMinutes: trackable.absorptionMinutes,
            ),
            DecayCalculator.generateLinearCurve(
              doses: allDoses,
              eliminationRate: trackable.eliminationRate!,
              startTime: boundary,
              endTime: nextBoundary,
              absorptionMinutes: trackable.absorptionMinutes,
            ),
          ),
          DecayModel.none => (0.0, <({DateTime time, double amount})>[]),
        };

        // Generate cumulative intake staircase when the toggle is on and
        // the trackable has a decay model. Uses todayDoses only — yesterday's
        // leftover caffeine shows on the decay curve but doesn't count as
        // today's intake. Empty list when off or no decay model.
        final cumulativePoints =
            (trackable.showCumulativeLine && model != DecayModel.none)
                ? DecayCalculator.generateCumulativeCurve(
                    doses: todayDoses,
                    startTime: boundary,
                    endTime: nextBoundary,
                  )
                : <({DateTime time, double amount})>[];

        // Compute today's taper target from the active plan (if any).
        // Uses the day boundary as the query date so the target aligns with
        // the app's definition of "today" (5 AM to 5 AM).
        final double? taperTarget;
        if (activePlan != null) {
          taperTarget = TaperCalculator.dailyTarget(
            startAmount: activePlan.startAmount,
            targetAmount: activePlan.targetAmount,
            startDate: activePlan.startDate,
            endDate: activePlan.endDate,
            queryDate: boundary,
          );
        } else {
          taperTarget = null;
        }

        return TrackableCardData(
          trackable: trackable,
          activeAmount: activeAmount,
          totalToday: DecayCalculator.totalRawAmount(todayDoses),
          curvePoints: curvePoints,
          dayBoundaryTime: boundary,
          lastDose: lastDose,
          thresholds: thresholdsList,
          cumulativePoints: cumulativePoints,
          taperTarget: taperTarget,
          activeTaperPlan: activePlan,
        );
      });
    },
  );
});

/// Combines four streams into a single stream of 4-tuples.
///
/// Emits whenever ANY stream emits, using the latest values from the others.
/// Like JavaScript's combineLatest from RxJS — waits for all four to emit at
/// least once, then re-emits whenever any changes.
///
/// We need this because Dart doesn't have a built-in combineLatest.
Stream<(List<DoseLog>, DoseLog?, List<Threshold>, TaperPlan?)> _combineStreams(
  Stream<List<DoseLog>> dosesStream,
  Stream<DoseLog?> lastDoseStream,
  Stream<List<Threshold>> thresholdsStream,
  Stream<TaperPlan?> taperPlanStream,
) {
  // Use a StreamController to manually merge the four streams.
  // Like creating a custom Livewire event listener that watches multiple sources.
  late StreamController<(List<DoseLog>, DoseLog?, List<Threshold>, TaperPlan?)> controller;
  List<DoseLog>? latestDoses;
  DoseLog? latestLastDose;
  bool lastDoseReceived = false;
  List<Threshold>? latestThresholds;
  TaperPlan? latestTaperPlan;
  bool taperPlanReceived = false;
  StreamSubscription? dosesSub;
  StreamSubscription? lastDoseSub;
  StreamSubscription? thresholdsSub;
  StreamSubscription? taperPlanSub;

  void tryEmit() {
    // Only emit once all four streams have sent at least one value.
    if (latestDoses != null && lastDoseReceived && latestThresholds != null && taperPlanReceived) {
      controller.add((latestDoses!, latestLastDose, latestThresholds!, latestTaperPlan));
    }
  }

  controller = StreamController<(List<DoseLog>, DoseLog?, List<Threshold>, TaperPlan?)>(
    onListen: () {
      dosesSub = dosesStream.listen(
        (doses) {
          latestDoses = doses;
          tryEmit();
        },
        onError: controller.addError,
      );
      lastDoseSub = lastDoseStream.listen(
        (dose) {
          latestLastDose = dose;
          lastDoseReceived = true;
          tryEmit();
        },
        onError: controller.addError,
      );
      thresholdsSub = thresholdsStream.listen(
        (thresholds) {
          latestThresholds = thresholds;
          tryEmit();
        },
        onError: controller.addError,
      );
      taperPlanSub = taperPlanStream.listen(
        (plan) {
          latestTaperPlan = plan;
          taperPlanReceived = true;
          tryEmit();
        },
        onError: controller.addError,
      );
    },
    onCancel: () {
      dosesSub?.cancel();
      lastDoseSub?.cancel();
      thresholdsSub?.cancel();
      taperPlanSub?.cancel();
    },
  );

  return controller.stream;
}
