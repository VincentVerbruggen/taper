import 'dart:math' as math;

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/data/decay_model.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/utils/day_boundary.dart';
import 'package:taper/utils/decay_calculator.dart';

/// Selected date range for the Analysis tab.
///
/// Stored as date-only values (midnight) because the UI is calendar-based.
/// The provider that runs SQL then converts these dates into day-boundary
/// timestamps (e.g., 05:00 -> next 05:00), matching the rest of the app.
///
/// Like a report filter form in Laravel:
///   /analysis?start=2026-02-01&end=2026-02-29
final analysisDateRangeProvider =
    NotifierProvider<AnalysisDateRangeNotifier, DateTimeRange>(
      AnalysisDateRangeNotifier.new,
    );

class AnalysisDateRangeNotifier extends Notifier<DateTimeRange> {
  @override
  DateTimeRange build() {
    // Default to "last 7 calendar days" ending today.
    // This gives useful data immediately on first open, like a dashboard
    // card that defaults to "last 7 days" instead of blank state.
    final now = ref.watch(nowProvider)();
    final end = _dateOnly(now);
    final start = end.subtract(const Duration(days: 6));
    return DateTimeRange(start: start, end: end);
  }

  /// Update the active range from the date-range picker.
  ///
  /// We normalize to date-only values so all downstream SQL window math is
  /// deterministic and not affected by picker/platform time components.
  void setRange(DateTimeRange range) {
    state = DateTimeRange(
      start: _dateOnly(range.start),
      end: _dateOnly(range.end),
    );
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}

/// Computed stats for one trackable over the selected analysis range.
class TrackableRangeStats {
  final Trackable trackable;
  final int doseCount;
  final int totalDays;
  final double totalAmount;
  final double averageDoseAmount;
  final double highestDoseAmount;
  final double lowestDoseAmount;
  final double highestDayTotal;
  final double lowestDayTotal;
  final double averageDayTotal;
  final double? highestActiveAmount;

  const TrackableRangeStats({
    required this.trackable,
    required this.doseCount,
    required this.totalDays,
    required this.totalAmount,
    required this.averageDoseAmount,
    required this.highestDoseAmount,
    required this.lowestDoseAmount,
    required this.highestDayTotal,
    required this.lowestDayTotal,
    required this.averageDayTotal,
    required this.highestActiveAmount,
  });

  /// Convenience flag for empty-state UI in each card.
  bool get hasDoses => doseCount > 0;
}

/// Entire payload for the Analysis screen.
///
/// One object keeps range metadata + per-trackable rows together, which is
/// easier for widgets than juggling many providers.
class AnalysisStatsData {
  final DateTimeRange selectedRange;
  final DateTime startBoundary;
  final DateTime endBoundaryExclusive;
  final int boundaryHour;
  final int totalDays;
  final int overallDoseCount;
  final double overallTotalAmount;
  final List<TrackableRangeStats> trackableStats;

  const AnalysisStatsData({
    required this.selectedRange,
    required this.startBoundary,
    required this.endBoundaryExclusive,
    required this.boundaryHour,
    required this.totalDays,
    required this.overallDoseCount,
    required this.overallTotalAmount,
    required this.trackableStats,
  });
}

/// Reactive analysis provider for the currently selected date range.
///
/// Dependencies:
/// - `analysisDateRangeProvider` (user filter)
/// - `dayBoundaryHourProvider` (global day definition)
/// - `trackablesProvider` (names/units/colors + display ordering)
/// - DB stream for logs in the computed SQL window
///
/// This mirrors a SQL + collection pipeline in Laravel where you fetch rows
/// for a date window, group by trackable/day, then compute aggregates.
final analysisStatsProvider = StreamProvider<AnalysisStatsData>((ref) {
  final db = ref.watch(databaseProvider);
  final selectedRange = ref.watch(analysisDateRangeProvider);
  final boundaryHour = ref.watch(dayBoundaryHourProvider);
  final trackablesAsync = ref.watch(trackablesProvider);

  // Convert calendar dates into the app's day-boundary window:
  // start = selected start date at boundary hour
  // end   = day AFTER selected end date at boundary hour (exclusive bound)
  //
  // Example with boundaryHour=5:
  // start=Feb 20, end=Feb 23  ->  window [Feb 20 05:00, Feb 24 05:00)
  final startBoundary = DateTime(
    selectedRange.start.year,
    selectedRange.start.month,
    selectedRange.start.day,
    boundaryHour,
  );
  final endBoundaryExclusive = DateTime(
    selectedRange.end.year,
    selectedRange.end.month,
    selectedRange.end.day + 1,
    boundaryHour,
  );

  // Inclusive day count of the selected range.
  final totalDays = math.max(
    1,
    endBoundaryExclusive.difference(startBoundary).inDays,
  );

  return trackablesAsync.when(
    loading: () => const Stream.empty(),
    error: (error, stack) => Stream.error(error, stack),
    data: (trackables) {
      // Include a lookback window for concentration calculations so doses
      // logged before the selected range can still contribute residual active
      // amount near the range start.
      //
      // We mirror dashboard logic:
      // - exponential => 10 half-lives (negligible after that)
      // - linear => 24h conservative lookback
      // - none => no lookback needed
      final maxLookbackHours = trackables.fold<double>(0, (
        maxHours,
        trackable,
      ) {
        final model = DecayModel.fromString(trackable.decayModel);
        final hours = switch (model) {
          DecayModel.exponential => (trackable.halfLifeHours ?? 0) * 10,
          DecayModel.linear => 24.0,
          DecayModel.none => 0.0,
        };
        return hours > maxHours ? hours : maxHours;
      });
      final decayQueryStart = startBoundary.subtract(
        Duration(minutes: (maxLookbackHours * 60).ceil()),
      );

      final logsStream = db.watchDoseLogsBetweenWithTrackable(
        decayQueryStart,
        endBoundaryExclusive,
      );

      return logsStream.map((rows) {
        // Bucket all logs by trackable ID for fast per-trackable aggregation.
        // Like: $rows->groupBy('trackable_id') in Laravel collections.
        final logsByTrackable = <int, List<DoseLog>>{};
        for (final row in rows) {
          logsByTrackable
              .putIfAbsent(row.trackable.id, () => <DoseLog>[])
              .add(row.doseLog);
        }

        // Show visible trackables by default, plus any hidden trackables that
        // still have doses in the selected range (so historical data is never
        // silently dropped from analysis).
        //
        // Archived trackables are excluded outright — archiving means "tucked
        // away everywhere", so they never appear in analysis even if they have
        // doses in the range. (Unarchiving brings their stats straight back.)
        final displayTrackables = trackables
            .where(
              (trackable) =>
                  !trackable.isArchived &&
                  (trackable.isVisible ||
                      logsByTrackable.containsKey(trackable.id)),
            )
            .toList(growable: false);

        final stats = <TrackableRangeStats>[];
        for (final trackable in displayTrackables) {
          final allTrackableDoses =
              logsByTrackable[trackable.id] ?? const <DoseLog>[];

          // Raw-dose stats should use only doses actually logged inside the
          // selected range (not lookback doses).
          final doses = allTrackableDoses
              .where((dose) => !dose.loggedAt.isBefore(startBoundary))
              .toList(growable: false);
          final doseCount = doses.length;

          final totalAmount = doses.fold<double>(
            0,
            (sum, dose) => sum + dose.amount,
          );

          // Aggregate per-day totals using the configured boundary hour.
          // This keeps "day high/low/avg" consistent with dashboard/log tabs.
          final totalsByDay = <DateTime, double>{};
          for (final dose in doses) {
            final bucket = dayBoundary(
              dose.loggedAt,
              boundaryHour: boundaryHour,
            );
            totalsByDay[bucket] = (totalsByDay[bucket] ?? 0) + dose.amount;
          }

          // Include zero-dose days in the range so "low day" and day-average
          // reflect the full selected window, not only days that had entries.
          final dayTotals = List<double>.generate(totalDays, (index) {
            final day = DateTime(
              startBoundary.year,
              startBoundary.month,
              startBoundary.day + index,
              boundaryHour,
            );
            return totalsByDay[day] ?? 0;
          });

          final highestDayTotal = dayTotals.fold<double>(
            0,
            (maxValue, value) => value > maxValue ? value : maxValue,
          );
          final lowestDayTotal = dayTotals.fold<double>(
            dayTotals.first,
            (minValue, value) => value < minValue ? value : minValue,
          );

          final highestDoseAmount = doses.fold<double>(
            0,
            (maxValue, dose) => dose.amount > maxValue ? dose.amount : maxValue,
          );

          final lowestDoseAmount = doseCount == 0
              ? 0.0
              : doses.fold<double>(
                  doses.first.amount,
                  (minValue, dose) =>
                      dose.amount < minValue ? dose.amount : minValue,
                );

          // Highest concentration = peak active amount across the selected range.
          //
          // We sample every 5 minutes (same cadence as dashboard curves) and
          // take the max active value. For trackables without a decay model,
          // concentration is undefined, so we return null for "N/A" in the UI.
          final model = DecayModel.fromString(trackable.decayModel);
          final double? highestActiveAmount = switch (model) {
            DecayModel.exponential =>
              trackable.halfLifeHours == null
                  ? null
                  : DecayCalculator.generateCurve(
                      doses: allTrackableDoses,
                      halfLifeHours: trackable.halfLifeHours!,
                      startTime: startBoundary,
                      endTime: endBoundaryExclusive,
                      absorptionMinutes: trackable.absorptionMinutes,
                    ).fold<double>(
                      0,
                      (maxValue, point) =>
                          point.amount > maxValue ? point.amount : maxValue,
                    ),
            DecayModel.linear =>
              trackable.eliminationRate == null
                  ? null
                  : DecayCalculator.generateLinearCurve(
                      doses: allTrackableDoses,
                      eliminationRate: trackable.eliminationRate!,
                      startTime: startBoundary,
                      endTime: endBoundaryExclusive,
                      absorptionMinutes: trackable.absorptionMinutes,
                    ).fold<double>(
                      0,
                      (maxValue, point) =>
                          point.amount > maxValue ? point.amount : maxValue,
                    ),
            DecayModel.none => null,
          };

          stats.add(
            TrackableRangeStats(
              trackable: trackable,
              doseCount: doseCount,
              totalDays: totalDays,
              totalAmount: totalAmount,
              averageDoseAmount: doseCount == 0 ? 0 : totalAmount / doseCount,
              highestDoseAmount: highestDoseAmount,
              lowestDoseAmount: lowestDoseAmount,
              highestDayTotal: highestDayTotal,
              lowestDayTotal: lowestDayTotal,
              averageDayTotal: totalAmount / totalDays,
              highestActiveAmount: highestActiveAmount,
            ),
          );
        }

        final overallDoseCount = stats.fold<int>(
          0,
          (sum, item) => sum + item.doseCount,
        );
        final overallTotalAmount = stats.fold<double>(
          0,
          (sum, item) => sum + item.totalAmount,
        );

        return AnalysisStatsData(
          selectedRange: selectedRange,
          startBoundary: startBoundary,
          endBoundaryExclusive: endBoundaryExclusive,
          boundaryHour: boundaryHour,
          totalDays: totalDays,
          overallDoseCount: overallDoseCount,
          overallTotalAmount: overallTotalAmount,
          trackableStats: stats,
        );
      });
    },
  );
});

// ---------------------------------------------------------------------------
// Single-trackable deep-dive analysis (the drill-down detail screen)
// ---------------------------------------------------------------------------

/// One day's consumption total, used to plot the trend chart.
///
/// A Dart record (like a lightweight anonymous struct / PHP associative array
/// with fixed keys). `day` is the day-boundary timestamp, `total` the summed
/// dose amount for that day.
typedef DailyTotalPoint = ({DateTime day, double total});

/// Family key for [trackableAnalysisProvider].
///
/// Records get value-based `==`/`hashCode` for free, so Riverpod memoizes one
/// provider instance per unique `(trackableId, start, end)` combination — just
/// like caching a report query keyed by its filters. `start`/`end` are
/// date-only (midnight); the provider converts them to day-boundary windows.
typedef TrackableAnalysisArgs = ({int trackableId, DateTime start, DateTime end});

/// Everything the single-trackable detail screen needs for one period, plus
/// the immediately-preceding equal-length period for comparison.
///
/// "Previous period" = the same number of days directly before the current
/// window. If you're viewing the last 7 days, the previous period is the 7
/// days before that — so you can see whether your taper is trending down.
class TrackableAnalysisData {
  final int trackableId;
  final int periodDays;

  /// Current-period daily totals, zero-filled for days with no doses so the
  /// chart and the low/average reflect the full window (not only logged days).
  final List<DailyTotalPoint> dailyTotals;

  final double total;
  final double averagePerDay;
  final double highestDayTotal;
  final double lowestDayTotal;
  final int doseCount;

  // Previous equal-length period (for the comparison card).
  final double previousTotal;
  final double previousAveragePerDay;
  final int previousDoseCount;

  const TrackableAnalysisData({
    required this.trackableId,
    required this.periodDays,
    required this.dailyTotals,
    required this.total,
    required this.averagePerDay,
    required this.highestDayTotal,
    required this.lowestDayTotal,
    required this.doseCount,
    required this.previousTotal,
    required this.previousAveragePerDay,
    required this.previousDoseCount,
  });

  bool get hasDoses => doseCount > 0;

  /// True when the previous window had at least one dose to compare against.
  bool get hasPreviousData => previousDoseCount > 0;

  /// Percent change of average/day vs the previous period.
  ///
  /// Negative = consumption went DOWN (taper working). Returns null when there
  /// is no prior data, because dividing by a zero baseline is undefined — the
  /// UI shows "no prior data" instead of a misleading number.
  double? get averageChangePercent {
    if (!hasPreviousData || previousAveragePerDay == 0) return null;
    return (averagePerDay - previousAveragePerDay) / previousAveragePerDay * 100;
  }
}

/// Reactive per-trackable analysis for a chosen date window.
///
/// Streams doses for the trackable across BOTH the current window and the
/// equal-length previous window in a single query, then buckets them into
/// per-day totals (using the configured day-boundary hour). Recomputes
/// automatically when doses change or the day-boundary setting changes.
final trackableAnalysisProvider =
    StreamProvider.family<TrackableAnalysisData, TrackableAnalysisArgs>((
      ref,
      args,
    ) {
      final db = ref.watch(databaseProvider);
      final boundaryHour = ref.watch(dayBoundaryHourProvider);

      // Convert the calendar dates into the app's day-boundary window, exactly
      // like analysisStatsProvider does (start at boundary hour, end exclusive
      // on the day AFTER the selected end date).
      final startBoundary = DateTime(
        args.start.year,
        args.start.month,
        args.start.day,
        boundaryHour,
      );
      final endBoundaryExclusive = DateTime(
        args.end.year,
        args.end.month,
        args.end.day + 1,
        boundaryHour,
      );
      final periodDays = math.max(
        1,
        endBoundaryExclusive.difference(startBoundary).inDays,
      );

      // Previous equal-length window sits directly before the current one and
      // ends exactly where it begins. Using day arithmetic (day - periodDays)
      // keeps the boundary hour stable across month rollovers.
      final prevStartBoundary = DateTime(
        startBoundary.year,
        startBoundary.month,
        startBoundary.day - periodDays,
        boundaryHour,
      );

      // One stream covering [prevStart, currentEnd) — both periods at once.
      final stream = db.watchDosesBetween(
        args.trackableId,
        prevStartBoundary,
        endBoundaryExclusive,
      );

      return stream.map((doses) {
        // Bucket every dose into its day-boundary day. Like groupBy(day) then
        // sum(amount) in a collection pipeline.
        final totalsByDay = <DateTime, double>{};
        for (final dose in doses) {
          final bucket = dayBoundary(dose.loggedAt, boundaryHour: boundaryHour);
          totalsByDay[bucket] = (totalsByDay[bucket] ?? 0) + dose.amount;
        }

        // Current-period daily totals, zero-filled across the whole window.
        final dailyTotals = <DailyTotalPoint>[];
        for (var i = 0; i < periodDays; i++) {
          final day = DateTime(
            startBoundary.year,
            startBoundary.month,
            startBoundary.day + i,
            boundaryHour,
          );
          dailyTotals.add((day: day, total: totalsByDay[day] ?? 0));
        }

        final total = dailyTotals.fold<double>(0, (sum, p) => sum + p.total);
        final highestDayTotal = dailyTotals.fold<double>(
          0,
          (maxValue, p) => p.total > maxValue ? p.total : maxValue,
        );
        final lowestDayTotal = dailyTotals.fold<double>(
          dailyTotals.first.total,
          (minValue, p) => p.total < minValue ? p.total : minValue,
        );

        // Current-period dose count = doses at/after the current start only.
        final doseCount = doses
            .where((d) => !d.loggedAt.isBefore(startBoundary))
            .length;

        // Previous-period totals: sum the zero-filled days of the prior window.
        var previousTotal = 0.0;
        for (var i = 0; i < periodDays; i++) {
          final day = DateTime(
            prevStartBoundary.year,
            prevStartBoundary.month,
            prevStartBoundary.day + i,
            boundaryHour,
          );
          previousTotal += totalsByDay[day] ?? 0;
        }
        final previousDoseCount = doses
            .where(
              (d) =>
                  d.loggedAt.isBefore(startBoundary) &&
                  !d.loggedAt.isBefore(prevStartBoundary),
            )
            .length;

        return TrackableAnalysisData(
          trackableId: args.trackableId,
          periodDays: periodDays,
          dailyTotals: dailyTotals,
          total: total,
          averagePerDay: total / periodDays,
          highestDayTotal: highestDayTotal,
          lowestDayTotal: lowestDayTotal,
          doseCount: doseCount,
          previousTotal: previousTotal,
          previousAveragePerDay: previousTotal / periodDays,
          previousDoseCount: previousDoseCount,
        );
      });
    });
