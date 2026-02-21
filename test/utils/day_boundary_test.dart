import 'package:flutter_test/flutter_test.dart';
import 'package:taper/utils/day_boundary.dart';

void main() {
  group('dayBoundary', () {
    test('7 AM returns same day 5 AM', () {
      // After the boundary → same day's boundary.
      final dt = DateTime(2026, 2, 21, 7, 30);
      final boundary = dayBoundary(dt);

      expect(boundary, DateTime(2026, 2, 21, 5, 0));
    });

    test('3 AM returns previous day 5 AM', () {
      // Before the boundary → yesterday's boundary.
      // 3 AM "feels like" the previous day (late night).
      final dt = DateTime(2026, 2, 21, 3, 0);
      final boundary = dayBoundary(dt);

      expect(boundary, DateTime(2026, 2, 20, 5, 0));
    });

    test('exactly 5:00 AM returns same day 5 AM', () {
      // Exactly at boundary → same day (>= check).
      final dt = DateTime(2026, 2, 21, 5, 0);
      final boundary = dayBoundary(dt);

      expect(boundary, DateTime(2026, 2, 21, 5, 0));
    });

    test('midnight returns previous day 5 AM', () {
      // Midnight = hour 0, which is before 5 → previous day.
      final dt = DateTime(2026, 2, 21, 0, 0);
      final boundary = dayBoundary(dt);

      expect(boundary, DateTime(2026, 2, 20, 5, 0));
    });

    test('11 PM returns same day 5 AM', () {
      // Late evening, still the same "day" that started at 5 AM.
      final dt = DateTime(2026, 2, 21, 23, 0);
      final boundary = dayBoundary(dt);

      expect(boundary, DateTime(2026, 2, 21, 5, 0));
    });

    test('handles month boundary rollover', () {
      // 3 AM on March 1st → February 28th 5 AM (or 29th in leap year).
      // DateTime handles this automatically.
      final dt = DateTime(2026, 3, 1, 3, 0);
      final boundary = dayBoundary(dt);

      // 2026 is not a leap year, so Feb has 28 days.
      expect(boundary, DateTime(2026, 2, 28, 5, 0));
    });

    test('custom boundary hour works', () {
      // Use 6 AM as the boundary instead of 5 AM.
      final dt = DateTime(2026, 2, 21, 5, 30);
      final boundary = dayBoundary(dt, boundaryHour: 6);

      // 5:30 AM is before 6 AM boundary → previous day.
      expect(boundary, DateTime(2026, 2, 20, 6, 0));
    });
  });

  group('nextDayBoundary', () {
    test('returns boundary + 24 hours', () {
      final dt = DateTime(2026, 2, 21, 7, 0);
      final next = nextDayBoundary(dt);

      // dayBoundary(7 AM Feb 21) = 5 AM Feb 21
      // next = 5 AM Feb 22
      expect(next, DateTime(2026, 2, 22, 5, 0));
    });

    test('before boundary: next is same calendar day', () {
      final dt = DateTime(2026, 2, 21, 3, 0);
      final next = nextDayBoundary(dt);

      // dayBoundary(3 AM Feb 21) = 5 AM Feb 20
      // next = 5 AM Feb 21
      expect(next, DateTime(2026, 2, 21, 5, 0));
    });

    test('handles year boundary rollover', () {
      // Late on Dec 31 → next boundary is Jan 1.
      final dt = DateTime(2026, 12, 31, 23, 0);
      final next = nextDayBoundary(dt);

      expect(next, DateTime(2027, 1, 1, 5, 0));
    });
  });
}
