import 'package:flutter_test/flutter_test.dart';
import 'package:taper/data/database.dart';
import 'package:taper/utils/decay_calculator.dart';

void main() {
  // Helper to create a DoseLog with just the fields we need for decay math.
  // The id and substanceId don't matter for pure math tests.
  DoseLog makeDose(double amount, DateTime loggedAt) {
    return DoseLog(id: 1, substanceId: 1, amount: amount, loggedAt: loggedAt);
  }

  group('activeDoseAt', () {
    test('at t=0, active equals original amount', () {
      // Right when you take the dose, 100% is still active.
      final loggedAt = DateTime(2026, 2, 21, 8, 0);
      final result = DecayCalculator.activeDoseAt(
        amount: 100,
        loggedAt: loggedAt,
        halfLifeHours: 5.0,
        queryTime: loggedAt, // Same time = 0 elapsed
      );

      expect(result, 100.0);
    });

    test('at t = halfLife, active is approximately half', () {
      // After one half-life (5h for caffeine), half remains.
      final loggedAt = DateTime(2026, 2, 21, 8, 0);
      final queryTime = loggedAt.add(const Duration(hours: 5));
      final result = DecayCalculator.activeDoseAt(
        amount: 100,
        loggedAt: loggedAt,
        halfLifeHours: 5.0,
        queryTime: queryTime,
      );

      // Should be exactly 50 (100 × 0.5^1)
      expect(result, closeTo(50.0, 0.01));
    });

    test('at t = 2×halfLife, active is approximately quarter', () {
      // After two half-lives, a quarter remains.
      final loggedAt = DateTime(2026, 2, 21, 8, 0);
      final queryTime = loggedAt.add(const Duration(hours: 10));
      final result = DecayCalculator.activeDoseAt(
        amount: 100,
        loggedAt: loggedAt,
        halfLifeHours: 5.0,
        queryTime: queryTime,
      );

      // Should be exactly 25 (100 × 0.5^2)
      expect(result, closeTo(25.0, 0.01));
    });

    test('dose in the future returns 0', () {
      // Can't be active before it's taken.
      final loggedAt = DateTime(2026, 2, 21, 10, 0);
      final queryTime = DateTime(2026, 2, 21, 8, 0); // 2h before dose
      final result = DecayCalculator.activeDoseAt(
        amount: 100,
        loggedAt: loggedAt,
        halfLifeHours: 5.0,
        queryTime: queryTime,
      );

      expect(result, 0.0);
    });

    test('beyond 10 half-lives returns 0', () {
      // After 10 half-lives (50h for caffeine), < 0.1% remains → negligible.
      final loggedAt = DateTime(2026, 2, 21, 8, 0);
      final queryTime = loggedAt.add(const Duration(hours: 51)); // > 10×5h
      final result = DecayCalculator.activeDoseAt(
        amount: 100,
        loggedAt: loggedAt,
        halfLifeHours: 5.0,
        queryTime: queryTime,
      );

      expect(result, 0.0);
    });

    test('exactly at 10 half-lives still calculates', () {
      // At exactly 10 half-lives (50h), hoursElapsed == halfLife * 10.
      // The check is >, not >=, so it still calculates.
      final loggedAt = DateTime(2026, 2, 21, 8, 0);
      final queryTime = loggedAt.add(const Duration(hours: 50)); // Exactly 10×5h
      final result = DecayCalculator.activeDoseAt(
        amount: 100,
        loggedAt: loggedAt,
        halfLifeHours: 5.0,
        queryTime: queryTime,
      );

      // 100 × 0.5^10 ≈ 0.0977
      expect(result, closeTo(0.0977, 0.01));
    });
  });

  group('totalActiveAt', () {
    test('sums active amounts from multiple doses', () {
      // Two 100mg doses, one at t=0 and one at t=-5h (one half-life ago).
      final now = DateTime(2026, 2, 21, 13, 0);
      final doses = [
        makeDose(100, now), // Just taken: 100mg active
        makeDose(100, now.subtract(const Duration(hours: 5))), // 5h ago: ~50mg
      ];

      final result = DecayCalculator.totalActiveAt(
        doses: doses,
        halfLifeHours: 5.0,
        queryTime: now,
      );

      // 100 + 50 = 150
      expect(result, closeTo(150.0, 0.01));
    });

    test('empty dose list returns 0', () {
      final result = DecayCalculator.totalActiveAt(
        doses: [],
        halfLifeHours: 5.0,
        queryTime: DateTime.now(),
      );

      expect(result, 0.0);
    });
  });

  group('generateCurve', () {
    test('produces correct number of points', () {
      // 1 hour window with 5-minute intervals = 13 points
      // (0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 minutes)
      final start = DateTime(2026, 2, 21, 8, 0);
      final end = DateTime(2026, 2, 21, 9, 0);

      final points = DecayCalculator.generateCurve(
        doses: [makeDose(100, start)],
        halfLifeHours: 5.0,
        startTime: start,
        endTime: end,
      );

      expect(points.length, 13);
    });

    test('first point matches dose amount at start time', () {
      final start = DateTime(2026, 2, 21, 8, 0);
      final end = DateTime(2026, 2, 21, 9, 0);

      final points = DecayCalculator.generateCurve(
        doses: [makeDose(100, start)],
        halfLifeHours: 5.0,
        startTime: start,
        endTime: end,
      );

      // At t=0 (start time = dose time), full amount is active.
      expect(points.first.time, start);
      expect(points.first.amount, closeTo(100.0, 0.01));
    });

    test('values decrease over time for a single dose', () {
      final start = DateTime(2026, 2, 21, 8, 0);
      final end = DateTime(2026, 2, 21, 13, 0); // 5 hours later

      final points = DecayCalculator.generateCurve(
        doses: [makeDose(100, start)],
        halfLifeHours: 5.0,
        startTime: start,
        endTime: end,
      );

      // First point should be higher than last point (decay).
      expect(points.first.amount, greaterThan(points.last.amount));
      // Last point after 5h = one half-life → ~50mg
      expect(points.last.amount, closeTo(50.0, 0.01));
    });

    test('empty doses produces all-zero curve', () {
      final start = DateTime(2026, 2, 21, 8, 0);
      final end = DateTime(2026, 2, 21, 9, 0);

      final points = DecayCalculator.generateCurve(
        doses: [],
        halfLifeHours: 5.0,
        startTime: start,
        endTime: end,
      );

      // All points should be zero.
      for (final point in points) {
        expect(point.amount, 0.0);
      }
    });

    test('custom interval changes point count', () {
      final start = DateTime(2026, 2, 21, 8, 0);
      final end = DateTime(2026, 2, 21, 9, 0);

      // 1 hour with 15-minute intervals = 5 points (0, 15, 30, 45, 60)
      final points = DecayCalculator.generateCurve(
        doses: [makeDose(100, start)],
        halfLifeHours: 5.0,
        startTime: start,
        endTime: end,
        intervalMinutes: 15,
      );

      expect(points.length, 5);
    });
  });

  group('totalRawAmount', () {
    test('sums all dose amounts without decay', () {
      final doses = [
        makeDose(90, DateTime(2026, 2, 21, 8, 0)),
        makeDose(90, DateTime(2026, 2, 21, 12, 0)),
      ];

      expect(DecayCalculator.totalRawAmount(doses), 180.0);
    });

    test('empty list returns 0', () {
      expect(DecayCalculator.totalRawAmount([]), 0.0);
    });
  });
}
