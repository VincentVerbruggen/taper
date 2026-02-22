import 'package:flutter_test/flutter_test.dart';
import 'package:taper/utils/taper_calculator.dart';

/// Simple test implementation of DoseLogLike.
/// Avoids importing Drift-generated code — pure math tests.
class _FakeDose implements DoseLogLike {
  @override
  final double amount;
  @override
  final DateTime loggedAt;

  _FakeDose(this.amount, this.loggedAt);
}

void main() {
  group('dailyTarget', () {
    test('at start date returns startAmount', () {
      final result = TaperCalculator.dailyTarget(
        startAmount: 400,
        targetAmount: 100,
        startDate: DateTime(2026, 2, 1, 5),
        endDate: DateTime(2026, 3, 1, 5),
        queryDate: DateTime(2026, 2, 1, 5),
      );

      // Day 0 of the plan: target = startAmount.
      expect(result, 400.0);
    });

    test('at end date returns targetAmount', () {
      final result = TaperCalculator.dailyTarget(
        startAmount: 400,
        targetAmount: 100,
        startDate: DateTime(2026, 2, 1, 5),
        endDate: DateTime(2026, 3, 1, 5),
        queryDate: DateTime(2026, 3, 1, 5),
      );

      // Last day of the plan: target = targetAmount.
      expect(result, 100.0);
    });

    test('at midpoint returns halfway between start and target', () {
      // 28-day plan: midpoint = day 14.
      final start = DateTime(2026, 2, 1, 5);
      final end = DateTime(2026, 3, 1, 5); // 28 days later
      final mid = DateTime(2026, 2, 15, 5); // 14 days from start

      final result = TaperCalculator.dailyTarget(
        startAmount: 400,
        targetAmount: 100,
        startDate: start,
        endDate: end,
        queryDate: mid,
      );

      // 400 + (100 - 400) * (14/28) = 400 - 150 = 250.
      expect(result, closeTo(250.0, 0.01));
    });

    test('before start date returns startAmount', () {
      final result = TaperCalculator.dailyTarget(
        startAmount: 400,
        targetAmount: 100,
        startDate: DateTime(2026, 2, 1, 5),
        endDate: DateTime(2026, 3, 1, 5),
        queryDate: DateTime(2026, 1, 15, 5), // 2 weeks before start
      );

      // Plan hasn't started yet: clamped to startAmount.
      expect(result, 400.0);
    });

    test('after end date returns targetAmount (maintenance mode)', () {
      final result = TaperCalculator.dailyTarget(
        startAmount: 400,
        targetAmount: 100,
        startDate: DateTime(2026, 2, 1, 5),
        endDate: DateTime(2026, 3, 1, 5),
        queryDate: DateTime(2026, 6, 1, 5), // 3 months after end
      );

      // Maintenance mode: indefinitely at targetAmount.
      expect(result, 100.0);
    });

    test('same-day plan (start == end) returns targetAmount', () {
      // Edge case: "instant change" plan where start == end date.
      final date = DateTime(2026, 2, 15, 5);
      final result = TaperCalculator.dailyTarget(
        startAmount: 400,
        targetAmount: 100,
        startDate: date,
        endDate: date,
        queryDate: date,
      );

      // totalDays = 0 → immediately returns targetAmount.
      expect(result, 100.0);
    });

    test('tapering up works (startAmount < targetAmount)', () {
      // Increasing plan: 100 → 400 over 28 days.
      final result = TaperCalculator.dailyTarget(
        startAmount: 100,
        targetAmount: 400,
        startDate: DateTime(2026, 2, 1, 5),
        endDate: DateTime(2026, 3, 1, 5),
        queryDate: DateTime(2026, 2, 15, 5), // midpoint
      );

      // 100 + (400 - 100) * (14/28) = 100 + 150 = 250.
      expect(result, closeTo(250.0, 0.01));
    });
  });

  group('generateTargetCurve', () {
    test('produces correct number of points (one per day inclusive)', () {
      // 7-day plan: start + 7 days = 8 points (day 0 through day 7).
      final points = TaperCalculator.generateTargetCurve(
        startAmount: 400,
        targetAmount: 100,
        startDate: DateTime(2026, 2, 1, 5),
        endDate: DateTime(2026, 2, 8, 5), // 7 days
      );

      // 8 points: Feb 1, 2, 3, 4, 5, 6, 7, 8.
      expect(points.length, 8);
    });

    test('first point is startAmount, last is targetAmount', () {
      final points = TaperCalculator.generateTargetCurve(
        startAmount: 400,
        targetAmount: 100,
        startDate: DateTime(2026, 2, 1, 5),
        endDate: DateTime(2026, 2, 8, 5),
      );

      expect(points.first.target, 400.0);
      expect(points.last.target, 100.0);
    });

    test('single-day plan produces 1 point', () {
      // start == end: just one point at targetAmount.
      final date = DateTime(2026, 2, 1, 5);
      final points = TaperCalculator.generateTargetCurve(
        startAmount: 400,
        targetAmount: 100,
        startDate: date,
        endDate: date,
      );

      expect(points.length, 1);
      expect(points.first.target, 100.0);
    });
  });

  group('dailyTotals', () {
    test('groups doses by day boundary and sums amounts', () {
      // Two doses on the same day (after 5 AM), one dose on the next day.
      final doses = [
        _FakeDose(90, DateTime(2026, 2, 21, 8, 0)),   // Day 1: 8 AM
        _FakeDose(63, DateTime(2026, 2, 21, 13, 30)),  // Day 1: 1:30 PM
        _FakeDose(90, DateTime(2026, 2, 22, 9, 0)),    // Day 2: 9 AM
      ];

      final totals = TaperCalculator.dailyTotals(
        doses: doses,
        boundaryHour: 5,
      );

      // Day 1 boundary = Feb 21 at 5 AM: 90 + 63 = 153.
      expect(totals[DateTime(2026, 2, 21, 5)], 153.0);
      // Day 2 boundary = Feb 22 at 5 AM: 90.
      expect(totals[DateTime(2026, 2, 22, 5)], 90.0);
    });

    test('empty doses returns empty map', () {
      final totals = TaperCalculator.dailyTotals(
        doses: [],
        boundaryHour: 5,
      );

      expect(totals, isEmpty);
    });

    test('dose before boundary hour belongs to previous day', () {
      // A dose at 3 AM on Feb 22 is "before" the 5 AM boundary,
      // so it counts as Feb 21's day.
      final doses = [
        _FakeDose(90, DateTime(2026, 2, 22, 3, 0)),
      ];

      final totals = TaperCalculator.dailyTotals(
        doses: doses,
        boundaryHour: 5,
      );

      // Should be grouped under Feb 21's boundary (5 AM Feb 21).
      expect(totals[DateTime(2026, 2, 21, 5)], 90.0);
      // Should NOT be under Feb 22's boundary.
      expect(totals[DateTime(2026, 2, 22, 5)], isNull);
    });

    test('respects custom boundary hour', () {
      // With boundary at 3 AM, a dose at 4 AM belongs to the current day.
      final doses = [
        _FakeDose(100, DateTime(2026, 2, 22, 4, 0)),
      ];

      final totals = TaperCalculator.dailyTotals(
        doses: doses,
        boundaryHour: 3,
      );

      // 4 AM is after the 3 AM boundary → belongs to Feb 22.
      expect(totals[DateTime(2026, 2, 22, 3)], 100.0);
    });
  });
}
