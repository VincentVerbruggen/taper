import 'package:taper/utils/day_boundary.dart';

/// Pure math for taper plan calculations — no DB access, no state.
///
/// Mirrors DecayCalculator's pattern: static methods, input → output.
/// Used by providers to compute daily targets and by the progress chart
/// to generate the target/actual curves.
///
/// A taper plan defines a linear ramp from startAmount to targetAmount
/// over a date range. Before the plan starts → startAmount. After it
/// ends → targetAmount (maintenance mode, indefinitely).
///
/// Like a PHP helper class:
///   TaperCalculator::dailyTarget($plan, $date)
class TaperCalculator {
  /// Calculate today's daily target for a taper plan.
  ///
  /// Linear interpolation from startAmount to targetAmount:
  ///   target = startAmount + (targetAmount - startAmount) × progress
  /// where progress = clamp(daysElapsed / totalDays, 0, 1).
  ///
  /// Edge cases:
  ///   - Before startDate → returns startAmount (plan hasn't begun)
  ///   - After endDate → returns targetAmount (maintenance mode)
  ///   - Same-day plan (start == end) → returns targetAmount immediately
  ///
  /// All dates are compared at day granularity (midnight), not clock time.
  /// The caller should pass day boundaries (e.g., 5 AM) for consistency
  /// with the rest of the app's day logic.
  static double dailyTarget({
    required double startAmount,
    required double targetAmount,
    required DateTime startDate,
    required DateTime endDate,
    required DateTime queryDate,
  }) {
    // Total days in the plan. If start == end, totalDays = 0 → instant change.
    final totalDays = endDate.difference(startDate).inDays;

    // Same-day plan: immediately return targetAmount.
    // Avoids division by zero below.
    if (totalDays <= 0) return targetAmount;

    // Days elapsed from plan start to query date.
    // Negative if before start (clamped to 0 below).
    final daysElapsed = queryDate.difference(startDate).inDays;

    // Clamp progress to [0, 1]: before start = 0%, after end = 100%.
    // Like PHP's min(1, max(0, $elapsed / $total)).
    final progress = (daysElapsed / totalDays).clamp(0.0, 1.0);

    // Linear interpolation between start and target amounts.
    // Works for both tapering down (start > target) and tapering up (start < target).
    return startAmount + (targetAmount - startAmount) * progress;
  }

  /// Generate one target point per day for the progress chart's diagonal line.
  ///
  /// Returns a list of (date, target) records from startDate to endDate inclusive.
  /// The chart draws this as a straight line from startAmount to targetAmount.
  ///
  /// Like: collect(range($startDate, $endDate))->map(fn($d) => [$d, target($d)])
  static List<({DateTime date, double target})> generateTargetCurve({
    required double startAmount,
    required double targetAmount,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final points = <({DateTime date, double target})>[];
    var current = startDate;

    // Walk day by day from start to end (inclusive).
    // DateTime comparison: !isAfter means <= (same day or before).
    while (!current.isAfter(endDate)) {
      final target = dailyTarget(
        startAmount: startAmount,
        targetAmount: targetAmount,
        startDate: startDate,
        endDate: endDate,
        queryDate: current,
      );
      points.add((date: current, target: target));
      // Add exactly one day. DateTime constructor handles month/year rollover.
      current = DateTime(current.year, current.month, current.day + 1,
          current.hour, current.minute);
    }

    return points;
  }

  /// Group doses by day boundary and sum their amounts.
  ///
  /// Returns a map of { dayBoundary → totalAmount } for the progress chart's
  /// "actual consumption" data series. Each key is a 5 AM boundary DateTime,
  /// each value is the sum of all dose amounts within that day.
  ///
  /// Like: $doses->groupBy(fn($d) => dayBoundary($d->logged_at))->map->sum('amount')
  static Map<DateTime, double> dailyTotals({
    required List<DoseLogLike> doses,
    required int boundaryHour,
  }) {
    final totals = <DateTime, double>{};

    for (final dose in doses) {
      // Use the same day boundary logic as the rest of the app.
      // A dose at 3 AM counts toward the previous day.
      final boundary = dayBoundary(dose.loggedAt, boundaryHour: boundaryHour);
      totals[boundary] = (totals[boundary] ?? 0.0) + dose.amount;
    }

    return totals;
  }
}

/// Minimal interface for dose-like objects, so TaperCalculator doesn't depend
/// on the Drift-generated DoseLog class directly. Makes unit testing easier —
/// tests can pass simple objects without needing a full database setup.
///
/// Like a PHP interface: interface DoseLogLike { public float $amount; public DateTime $loggedAt; }
abstract class DoseLogLike {
  double get amount;
  DateTime get loggedAt;
}
