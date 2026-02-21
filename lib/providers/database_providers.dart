import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/utils/day_boundary.dart';
import 'package:taper/utils/decay_calculator.dart';

/// databaseProvider = the app's database singleton.
///
/// Like Laravel's `$app->singleton()`:
///   `$this->app->singleton(AppDatabase::class, fn() => new AppDatabase())`;
///
/// Once created, it lives forever. Every widget that needs the database
/// calls ref.read(databaseProvider) or ref.watch(databaseProvider).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();

  // ref.onDispose = cleanup when provider is destroyed.
  // Like __destruct() in PHP — close the DB connection.
  ref.onDispose(() => db.close());

  return db;
});

/// substancesProvider = a reactive stream of all substances.
///
/// Like a Livewire computed property backed by a DB query:
///   public function getSubstancesProperty() {
///       return Substance::orderBy('name')->get();
///   }
///
/// Except it's push-based, not polling. When you insert/update/delete a substance,
/// Drift's .watch() automatically emits the fresh list, and every widget
/// watching this provider re-renders instantly.
///
/// The AsyncValue wrapper handles three states:
///   - AsyncLoading (spinner while DB query runs first time)
///   - AsyncData (the substance list)
///   - AsyncError (if something goes wrong)
final substancesProvider = StreamProvider<List<Substance>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllSubstances();
});

/// visibleSubstancesProvider = reactive stream of visible-only substances.
///
/// Used by the Log form dropdown — hidden substances don't appear.
/// The Substances management screen uses substancesProvider instead (shows ALL).
///
/// Like a Livewire computed property with a scope:
///   public function getVisibleSubstancesProperty() {
///       return Substance::visible()->orderBy('name')->get();
///   }
final visibleSubstancesProvider = StreamProvider<List<Substance>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchVisibleSubstances();
});

/// doseLogsProvider = reactive stream of recent dose logs with substance names.
///
/// Like: DoseLog::with('substance')->latest()->limit(50)->get()
/// ...but reactive. Used by the Log screen's recent doses list.
final doseLogsProvider = StreamProvider<List<DoseLogWithSubstance>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchRecentDoseLogs();
});

/// Data class holding everything a substance card needs to display.
///
/// Like a Laravel Resource/DTO that bundles the model with computed values:
///   class SubstanceCardResource extends JsonResource {
///       public function toArray() {
///           return ['substance' => $this, 'activeAmount' => ..., 'curvePoints' => ...];
///       }
///   }
class SubstanceCardData {
  final Substance substance;

  /// Decayed amount at the moment of calculation (e.g., "42 mg active").
  /// 0 for substances without a half-life (like Water).
  final double activeAmount;

  /// Raw sum of all doses since the day boundary (e.g., "180 mg today").
  /// No decay applied — just total consumed.
  final double totalToday;

  /// Chart data: sampled every 5 minutes from day boundary to next boundary.
  /// Empty for substances without a half-life.
  final List<({DateTime time, double amount})> curvePoints;

  /// The day boundary (5 AM) used to generate the curve.
  /// Passed to the chart so X-axis labels can show clock times.
  final DateTime dayBoundaryTime;

  /// Most recent dose for this substance (for "Repeat Last" button).
  /// null if no doses ever logged.
  final DoseLog? lastDose;

  SubstanceCardData({
    required this.substance,
    required this.activeAmount,
    required this.totalToday,
    required this.curvePoints,
    required this.dayBoundaryTime,
    required this.lastDose,
  });
}

/// Per-substance card data provider, keyed by substance ID.
///
/// StreamProvider.family creates a separate provider instance for each substance,
/// so cards load independently (staggered). Each watches its own dose stream.
///
/// Like a Livewire component with a mount($substanceId) parameter — each card
/// is its own reactive unit with its own DB query.
///
/// The provider combines two streams (doses + lastDose) using Rx.combineLatest
/// pattern via StreamZip, then runs the decay calculator on each emission.
final substanceCardDataProvider =
    StreamProvider.family<SubstanceCardData, int>((ref, substanceId) {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final boundary = dayBoundary(now);
  final nextBoundary = nextDayBoundary(now);

  // First, get the substance itself. We need its halfLifeHours to calculate
  // the decay window. Watch it reactively in case it gets edited.
  final substancesAsync = ref.watch(substancesProvider);

  return substancesAsync.when(
    loading: () => const Stream.empty(),
    error: (e, s) => Stream.error(e, s),
    data: (substances) {
      final substance = substances.where((s) => s.id == substanceId).firstOrNull;
      if (substance == null) return Stream.error('Substance not found');

      // Calculate the dose query window:
      // For substances WITH a half-life, we look back further than the day
      // boundary to capture doses that are still decaying. A dose from yesterday
      // might still contribute active amount today.
      // "10 × halfLife" hours back = the point where < 0.1% remains.
      // Using 10 (not 5) avoids visual artifacts where the curve abruptly drops.
      // For substances WITHOUT a half-life, just use the day boundary.
      final dosesSince = substance.halfLifeHours != null
          ? boundary.subtract(
              Duration(hours: (substance.halfLifeHours! * 10).ceil()),
            )
          : boundary;

      // Watch two streams: all relevant doses + the most recent dose (for Repeat Last).
      final dosesStream = db.watchDosesSince(substanceId, dosesSince);
      final lastDoseStream = db.watchLastDose(substanceId);

      // Combine both streams. When either emits, recalculate the card data.
      // Like Livewire's computed properties that depend on multiple queries —
      // when either source changes, the whole card re-renders.
      return _combineStreams(dosesStream, lastDoseStream).map((combined) {
        final allDoses = combined.$1;
        final lastDose = combined.$2;

        // Filter doses to just "today" (since day boundary) for the raw total.
        final todayDoses =
            allDoses.where((d) => !d.loggedAt.isBefore(boundary)).toList();

        if (substance.halfLifeHours != null) {
          // Substance WITH half-life: calculate active amount + curve.
          final halfLife = substance.halfLifeHours!;
          final activeAmount = DecayCalculator.totalActiveAt(
            doses: allDoses,
            halfLifeHours: halfLife,
            queryTime: now,
          );
          final curvePoints = DecayCalculator.generateCurve(
            doses: allDoses,
            halfLifeHours: halfLife,
            startTime: boundary,
            endTime: nextBoundary,
          );

          return SubstanceCardData(
            substance: substance,
            activeAmount: activeAmount,
            totalToday: DecayCalculator.totalRawAmount(todayDoses),
            curvePoints: curvePoints,
            dayBoundaryTime: boundary,
            lastDose: lastDose,
          );
        } else {
          // Substance WITHOUT half-life (e.g., Water): no decay, just totals.
          return SubstanceCardData(
            substance: substance,
            activeAmount: 0,
            totalToday: DecayCalculator.totalRawAmount(todayDoses),
            curvePoints: [],
            dayBoundaryTime: boundary,
            lastDose: lastDose,
          );
        }
      });
    },
  );
});

/// Combines two streams into a single stream of tuples.
///
/// Emits whenever EITHER stream emits, using the latest value from the other.
/// Like JavaScript's combineLatest from RxJS — waits for both to emit at
/// least once, then re-emits whenever either changes.
///
/// We need this because Dart doesn't have a built-in combineLatest.
Stream<(List<DoseLog>, DoseLog?)> _combineStreams(
  Stream<List<DoseLog>> dosesStream,
  Stream<DoseLog?> lastDoseStream,
) {
  // Use a StreamController to manually merge the two streams.
  // Like creating a custom Livewire event listener that watches two sources.
  late StreamController<(List<DoseLog>, DoseLog?)> controller;
  List<DoseLog>? latestDoses;
  DoseLog? latestLastDose;
  bool lastDoseReceived = false;
  StreamSubscription? dosesSub;
  StreamSubscription? lastDoseSub;

  void tryEmit() {
    // Only emit once both streams have sent at least one value.
    if (latestDoses != null && lastDoseReceived) {
      controller.add((latestDoses!, latestLastDose));
    }
  }

  controller = StreamController<(List<DoseLog>, DoseLog?)>(
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
    },
    onCancel: () {
      dosesSub?.cancel();
      lastDoseSub?.cancel();
    },
  );

  return controller.stream;
}
