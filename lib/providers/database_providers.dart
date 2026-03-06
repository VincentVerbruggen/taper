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
final presetsProvider = StreamProvider.family<List<Preset>, int>((
  ref,
  trackableId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchPresets(trackableId);
});

/// Reactive stream of thresholds for a specific trackable, keyed by trackable ID.
///
/// StreamProvider.family creates a separate provider per trackable ID.
/// Used by the edit trackable screen to manage thresholds.
///
/// Like: Threshold::where('trackable_id', $id)->get()
final thresholdsProvider = StreamProvider.family<List<Threshold>, int>((
  ref,
  trackableId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchThresholds(trackableId);
});

/// Reactive stream of time-based targets for a specific trackable.
final targetsProvider = StreamProvider.family<List<Target>, int>((
  ref,
  trackableId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchTargets(trackableId);
});

/// Reactive stream of taper plans for a specific trackable, keyed by trackable ID.
///
/// StreamProvider.family creates a separate provider per trackable ID.
/// Used by the edit trackable screen to list all plans (active + inactive).
///
/// Like: TaperPlan::where('trackable_id', $id)->orderByDesc('start_date')->get()
final taperPlansProvider = StreamProvider.family<List<TaperPlan>, int>((
  ref,
  trackableId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchTaperPlans(trackableId);
});

/// Reactive stream of reminders for a specific trackable, keyed by trackable ID.
///
/// StreamProvider.family creates a separate provider per trackable ID.
/// Used by the reminders screen and the edit trackable navigation tile count.
///
/// Like: Reminder::where('trackable_id', $id)->orderBy('label')->get()
final remindersProvider = StreamProvider.family<List<Reminder>, int>((
  ref,
  trackableId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchReminders(trackableId);
});

/// Reactive stream of the active taper plan for a specific trackable.
///
/// Returns null if no active plan exists. Used by the dashboard card
/// to show today's target and the "Progress" button.
///
/// Like: TaperPlan::where('trackable_id', $id)->where('is_active', true)->first()
final activeTaperPlanProvider = StreamProvider.family<TaperPlan?, int>((
  ref,
  trackableId,
) {
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

/// Selected date for log-oriented day browsing (Log tab + trackable log).
///
/// null = today (live/current day window)
/// Non-null = an explicit day boundary (past or future)
///
/// This provider no longer drives dashboard cards; dashboard is always live.
/// Think of this like a "day filter" query param for log pages only.
final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime?>(
  SelectedDateNotifier.new,
);

class SelectedDateNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Set to a specific date to view that day's data.
  void selectDate(DateTime date) {
    // Normalize to this app's day-boundary timestamp (e.g., 05:00).
    // Date pickers return midnight, but card/log queries are boundary-based.
    final boundaryHour = ref.read(dayBoundaryHourProvider);
    final selectedBoundary = DateTime(
      date.year,
      date.month,
      date.day,
      boundaryHour,
    );
    final now = ref.read(nowProvider)();
    final todayBoundary = dayBoundary(now, boundaryHour: boundaryHour);

    // Keep today as null/live mode, but allow both past and future explicit days.
    state = selectedBoundary == todayBoundary ? null : selectedBoundary;
  }

  /// Reset to live/today view.
  void goToToday() => state = null;

  /// Go to the previous day.
  void previousDay() {
    final boundaryHour = ref.read(dayBoundaryHourProvider);
    final now = ref.read(nowProvider)();
    final current = state ?? dayBoundary(now, boundaryHour: boundaryHour);
    state = current.subtract(const Duration(days: 1));
  }

  /// Go to the next day.
  ///
  /// From null/live (today), this moves to tomorrow as an explicit date.
  /// From any explicit date, it advances by one day (including future days).
  void nextDay() {
    final boundaryHour = ref.read(dayBoundaryHourProvider);
    final now = ref.read(nowProvider)();
    final todayBoundary = dayBoundary(now, boundaryHour: boundaryHour);
    final current = state ?? todayBoundary;
    state = current.add(const Duration(days: 1));
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

  /// Raw sum of planned doses in the selected day window.
  /// Kept separate from consumed totals for "actual vs projected" UI.
  final double plannedToday;

  /// Chart data: sampled every 5 minutes from day boundary to next boundary.
  /// Empty for trackables without a half-life.
  final List<({DateTime time, double amount})> curvePoints;

  /// Projected chart data (actual + planned doses) for the same window.
  /// Drawn as an overlay to preview where levels could go if plans are followed.
  final List<({DateTime time, double amount})> projectedCurvePoints;

  /// Whether planned doses exist in the loaded query window.
  /// Used to avoid drawing a duplicate projected line when there are none.
  final bool hasPlannedDoses;

  /// The day boundary (5 AM today) used to generate the curve.
  /// Passed to the chart so X-axis labels can show clock times.
  final DateTime dayBoundaryTime;

  /// The next day boundary (5 AM tomorrow).
  /// Used by the chart to draw a vertical marker at the end of "today".
  final DateTime nextDayBoundaryTime;

  /// Most recent dose for this trackable (for "Repeat Last" button).
  /// null if no doses ever logged.
  final DoseLog? lastDose;

  /// Threshold lines to draw on the chart (name + amount pairs).
  /// Each one appears as a dashed horizontal line.
  final List<Threshold> thresholds;

  /// Time-based targets to draw on the chart.
  final List<Target> targets;

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
    required this.plannedToday,
    required this.curvePoints,
    required this.projectedCurvePoints,
    required this.hasPlannedDoses,
    required this.dayBoundaryTime,
    required this.nextDayBoundaryTime,
    required this.lastDose,
    required this.thresholds,
    required this.targets,
    required this.cumulativePoints,
    this.taperTarget,
    this.activeTaperPlan,
  });
}

/// Shared implementation for building trackable card data streams.
///
/// [selectedDate] controls whether calculations are anchored to:
///   - null: current live day (dashboard behavior)
///   - non-null: historical selected day (trackable log behavior)
Stream<TrackableCardData> _trackableCardDataStream(
  Ref ref,
  int trackableId, {
  required DateTime? selectedDate,
}) {
  final db = ref.watch(databaseProvider);
  // Watch the day boundary hour setting so cards recalculate when it changes.
  final boundaryHour = ref.watch(dayBoundaryHourProvider);

  // Use a provider-driven clock so widget tests can freeze "now" and assert
  // deterministic day labels/queries.
  final now = ref.watch(nowProvider)();

  // When viewing a past date, use that date's boundary; otherwise use today.
  final boundary = selectedDate != null
      ? DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          boundaryHour,
        )
      : dayBoundary(now, boundaryHour: boundaryHour);
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
      final trackable = trackables
          .where((t) => t.id == trackableId)
          .firstOrNull;
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

      // Watch five streams: doses, last dose, thresholds, taper plan, and targets.
      final dosesStream = db.watchDosesSince(trackableId, dosesSince);
      final lastDoseStream = db.watchLastDose(trackableId);
      final thresholdsStream = db.watchThresholds(trackableId);
      final taperPlanStream = db.watchActiveTaperPlan(trackableId);
      final targetsStream = db.watchTargets(trackableId);

      // Combine all five streams. When any emits, recalculate the card data.
      // Like Livewire's computed properties that depend on multiple queries —
      // when any source changes, the whole card re-renders.
      return _combineStreams(
        dosesStream,
        lastDoseStream,
        thresholdsStream,
        taperPlanStream,
        targetsStream,
      ).map((combined) {
        final allDoses = combined.$1;
        final lastDose = combined.$2;
        final thresholdsList = combined.$3;
        final activePlan = combined.$4;
        final targetsList = combined.$5;

        // Planned doses are projections, so we keep them separate from actual
        // consumed doses for stats and "Repeat Last" semantics.
        final actualDoses = allDoses.where((d) => !d.isPlanned).toList();
        final plannedDoses = allDoses.where((d) => d.isPlanned).toList();
        final projectedDoses = [...actualDoses, ...plannedDoses];

        // Filter to the selected day for raw totals.
        final todayActualDoses = actualDoses
            .where((d) => !d.loggedAt.isBefore(boundary))
            .toList();
        final todayPlannedDoses = plannedDoses
            .where((d) => !d.loggedAt.isBefore(boundary))
            .toList();

        // Extended time window: 6h before day boundary and 6h after next boundary.
        // This lets the chart show yesterday's decay trailing in from the left
        // and tomorrow's projected decay on the right. Users can pan to see these.
        // Like a Laravel report that shows a buffer zone around today's date range.
        final extendedStart = boundary.subtract(const Duration(hours: 6));
        final extendedEnd = nextBoundary.add(const Duration(hours: 6));

        // 3-way switch on decay model — each branch calculates active amount
        // and curve points using its own formula.
        // Curves use the extended window for multi-day visibility.
        final (
          double activeAmount,
          List<({DateTime time, double amount})> curvePoints,
          List<({DateTime time, double amount})> projectedCurvePoints,
        ) = switch (model) {
          DecayModel.exponential => (
            DecayCalculator.totalActiveAt(
              doses: actualDoses,
              halfLifeHours: trackable.halfLifeHours!,
              queryTime: queryTime,
              absorptionMinutes: trackable.absorptionMinutes,
            ),
            DecayCalculator.generateCurve(
              doses: actualDoses,
              halfLifeHours: trackable.halfLifeHours!,
              startTime: extendedStart,
              endTime: extendedEnd,
              absorptionMinutes: trackable.absorptionMinutes,
            ),
            DecayCalculator.generateCurve(
              doses: projectedDoses,
              halfLifeHours: trackable.halfLifeHours!,
              startTime: extendedStart,
              endTime: extendedEnd,
              absorptionMinutes: trackable.absorptionMinutes,
            ),
          ),
          DecayModel.linear => (
            DecayCalculator.totalActiveLinearAt(
              doses: actualDoses,
              eliminationRate: trackable.eliminationRate!,
              queryTime: queryTime,
              absorptionMinutes: trackable.absorptionMinutes,
            ),
            DecayCalculator.generateLinearCurve(
              doses: actualDoses,
              eliminationRate: trackable.eliminationRate!,
              startTime: extendedStart,
              endTime: extendedEnd,
              absorptionMinutes: trackable.absorptionMinutes,
            ),
            DecayCalculator.generateLinearCurve(
              doses: projectedDoses,
              eliminationRate: trackable.eliminationRate!,
              startTime: extendedStart,
              endTime: extendedEnd,
              absorptionMinutes: trackable.absorptionMinutes,
            ),
          ),
          DecayModel.none => (
            0.0,
            <({DateTime time, double amount})>[],
            <({DateTime time, double amount})>[],
          ),
        };

        // Generate cumulative intake staircase for the extended window.
        // Uses actual doses only — yesterday's leftover caffeine shows on the
        // decay curve but doesn't count as today's intake.
        final cumulativePoints = (model != DecayModel.none)
            ? DecayCalculator.generateCumulativeCurve(
                doses: todayActualDoses,
                startTime: extendedStart,
                endTime: extendedEnd,
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
          totalToday: DecayCalculator.totalRawAmount(todayActualDoses),
          plannedToday: DecayCalculator.totalRawAmount(todayPlannedDoses),
          curvePoints: curvePoints,
          projectedCurvePoints: projectedCurvePoints,
          hasPlannedDoses: plannedDoses.isNotEmpty,
          dayBoundaryTime: boundary,
          nextDayBoundaryTime: nextBoundary,
          lastDose: lastDose,
          thresholds: thresholdsList,
          targets: targetsList,
          cumulativePoints: cumulativePoints,
          taperTarget: taperTarget,
          activeTaperPlan: activePlan,
        );
      });
    },
  );
}

/// Per-trackable card data provider for Dashboard cards.
///
/// Important: Dashboard must always reflect "today/live" data regardless of
/// date selection in log-related screens.
final trackableCardDataProvider = StreamProvider.family<TrackableCardData, int>(
  (ref, trackableId) {
    return _trackableCardDataStream(ref, trackableId, selectedDate: null);
  },
);

/// Per-trackable card data provider that follows selectedDateProvider.
///
/// Used by day-specific log surfaces (for example TrackableLogScreen graph)
/// where users intentionally browse historical days.
final trackableCardDataForSelectedDateProvider =
    StreamProvider.family<TrackableCardData, int>((ref, trackableId) {
      final selectedDate = ref.watch(selectedDateProvider);
      return _trackableCardDataStream(
        ref,
        trackableId,
        selectedDate: selectedDate,
      );
    });

/// Reactive stream of dose logs for the currently selected log day.
///
/// This powers the Log tab's "single-day" view:
///   - selectedDateProvider == null  -> today (live day boundary window)
///   - selectedDateProvider != null  -> that specific past day window
final selectedDayDoseLogsProvider = StreamProvider<List<DoseLogWithTrackable>>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  final boundaryHour = ref.watch(dayBoundaryHourProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  final now = ref.watch(nowProvider)();

  final startBoundary = selectedDate != null
      ? DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          boundaryHour,
        )
      : dayBoundary(now, boundaryHour: boundaryHour);
  final endBoundary = DateTime(
    startBoundary.year,
    startBoundary.month,
    startBoundary.day + 1,
    boundaryHour,
  );

  return db.watchDoseLogsBetweenWithTrackable(startBoundary, endBoundary);
});

/// Combines five streams into a single stream of 5-tuples.
///
/// Emits whenever ANY stream emits, using the latest values from the others.
/// Like JavaScript's combineLatest from RxJS — waits for all five to emit at
/// least once, then re-emits whenever any changes.
Stream<(List<DoseLog>, DoseLog?, List<Threshold>, TaperPlan?, List<Target>)>
_combineStreams(
  Stream<List<DoseLog>> dosesStream,
  Stream<DoseLog?> lastDoseStream,
  Stream<List<Threshold>> thresholdsStream,
  Stream<TaperPlan?> taperPlanStream,
  Stream<List<Target>> targetsStream,
) {
  // Use a StreamController to manually merge the streams.
  late StreamController<
    (List<DoseLog>, DoseLog?, List<Threshold>, TaperPlan?, List<Target>)
  >
  controller;
  List<DoseLog>? latestDoses;
  DoseLog? latestLastDose;
  bool lastDoseReceived = false;
  List<Threshold>? latestThresholds;
  TaperPlan? latestTaperPlan;
  bool taperPlanReceived = false;
  List<Target>? latestTargets;
  StreamSubscription? dosesSub;
  StreamSubscription? lastDoseSub;
  StreamSubscription? thresholdsSub;
  StreamSubscription? taperPlanSub;
  StreamSubscription? targetsSub;

  void tryEmit() {
    // Only emit once all streams have sent at least one value.
    if (latestDoses != null &&
        lastDoseReceived &&
        latestThresholds != null &&
        taperPlanReceived &&
        latestTargets != null) {
      controller.add((
        latestDoses!,
        latestLastDose,
        latestThresholds!,
        latestTaperPlan,
        latestTargets!,
      ));
    }
  }

  controller =
      StreamController<
        (List<DoseLog>, DoseLog?, List<Threshold>, TaperPlan?, List<Target>)
      >(
        onListen: () {
          dosesSub = dosesStream.listen((doses) {
            latestDoses = doses;
            tryEmit();
          }, onError: controller.addError);
          lastDoseSub = lastDoseStream.listen((dose) {
            latestLastDose = dose;
            lastDoseReceived = true;
            tryEmit();
          }, onError: controller.addError);
          thresholdsSub = thresholdsStream.listen((thresholds) {
            latestThresholds = thresholds;
            tryEmit();
          }, onError: controller.addError);
          taperPlanSub = taperPlanStream.listen((plan) {
            latestTaperPlan = plan;
            taperPlanReceived = true;
            tryEmit();
          }, onError: controller.addError);
          targetsSub = targetsStream.listen((targets) {
            latestTargets = targets;
            tryEmit();
          }, onError: controller.addError);
        },
        onCancel: () {
          dosesSub?.cancel();
          lastDoseSub?.cancel();
          thresholdsSub?.cancel();
          taperPlanSub?.cancel();
          targetsSub?.cancel();
        },
      );

  return controller.stream;
}
