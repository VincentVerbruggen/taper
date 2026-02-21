import 'dart:math';

import 'package:taper/data/database.dart';

/// Pure math for pharmacokinetic decay calculations.
///
/// All methods are static — no state, no DB access. This makes them trivially
/// unit-testable (just input → output, like a PHP helper class with static methods).
///
/// The core formula for exponential decay:
///   active_amount(t) = dose × 0.5^(hours_elapsed / half_life)
///
/// This models how the body metabolizes substances: after one half-life,
/// half the substance remains. After two half-lives, a quarter remains, etc.
/// Like compound interest in reverse.
class DecayCalculator {
  /// Calculate how much of a single dose is still active at [queryTime].
  ///
  /// Formula: amount × 0.5^(hoursElapsed / halfLifeHours)
  ///
  /// Returns 0 if:
  ///   - The dose is in the future (hasn't been taken yet)
  ///   - More than 10 half-lives have passed (< 0.1% remains, negligible)
  ///
  /// The 10-half-life cutoff is generous to avoid visual artifacts where
  /// the curve abruptly drops to zero. At 10 half-lives, only ~0.1% remains.
  /// Like a WHERE clause filtering out irrelevant old records.
  static double activeDoseAt({
    required double amount,
    required DateTime loggedAt,
    required double halfLifeHours,
    required DateTime queryTime,
  }) {
    // Hours between dose and query time. negative = dose is in the future.
    final hoursElapsed = queryTime.difference(loggedAt).inMinutes / 60.0;

    // Future dose → not active yet.
    if (hoursElapsed < 0) return 0.0;

    // Beyond 10 half-lives → negligible amount (< 0.1%), skip calculation.
    if (hoursElapsed > halfLifeHours * 10) return 0.0;

    // Core decay formula: amount × 0.5^(elapsed / halfLife)
    // pow(0.5, 1.0) = 0.5 (one half-life = half remaining)
    // pow(0.5, 2.0) = 0.25 (two half-lives = quarter remaining)
    return amount * pow(0.5, hoursElapsed / halfLifeHours);
  }

  /// Sum the active amounts of multiple doses at [queryTime].
  ///
  /// Each dose decays independently — the body processes them in parallel.
  /// This is why you can feel the cumulative effect of multiple coffees:
  /// each one is decaying on its own timeline.
  ///
  /// Like: $doses->sum(fn($d) => activeDoseAt($d, $queryTime))
  static double totalActiveAt({
    required List<DoseLog> doses,
    required double halfLifeHours,
    required DateTime queryTime,
  }) {
    return doses.fold(0.0, (sum, dose) {
      return sum +
          activeDoseAt(
            amount: dose.amount,
            loggedAt: dose.loggedAt,
            halfLifeHours: halfLifeHours,
            queryTime: queryTime,
          );
    });
  }

  /// Generate chart data points by sampling the total active amount over time.
  ///
  /// Produces a point every [intervalMinutes] (default 5) from [startTime] to
  /// [endTime]. Each point is the sum of all still-active doses at that moment.
  ///
  /// Returns a list of records (Dart 3 syntax) with time + amount.
  /// Like generating a time series: for each 5-min slot, run the decay formula.
  ///
  /// 5-minute intervals give smooth curves without excessive points.
  /// A 24-hour window = 288 points — plenty for a chart, cheap to compute.
  static List<({DateTime time, double amount})> generateCurve({
    required List<DoseLog> doses,
    required double halfLifeHours,
    required DateTime startTime,
    required DateTime endTime,
    int intervalMinutes = 5,
  }) {
    final points = <({DateTime time, double amount})>[];
    var current = startTime;

    while (!current.isAfter(endTime)) {
      final amount = totalActiveAt(
        doses: doses,
        halfLifeHours: halfLifeHours,
        queryTime: current,
      );
      points.add((time: current, amount: amount));
      current = current.add(Duration(minutes: intervalMinutes));
    }

    return points;
  }

  /// Simple sum of dose amounts — no decay, just raw totals.
  ///
  /// Used for "180 mg today" stat (total consumed, regardless of how much
  /// has been metabolized). Like: $doses->sum('amount')
  static double totalRawAmount(List<DoseLog> doses) {
    return doses.fold(0.0, (sum, dose) => sum + dose.amount);
  }
}
