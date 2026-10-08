import 'package:flutter_test/flutter_test.dart';
import 'package:taper/utils/template_time.dart';

void main() {
  group('toTemplateTime', () {
    test('zero-pads and drops seconds', () {
      expect(toTemplateTime(DateTime(2026, 2, 23, 8, 5, 42)), '08:05');
    });

    test('formats late evening times', () {
      expect(toTemplateTime(DateTime(2026, 2, 23, 23, 59)), '23:59');
    });
  });

  group('placeOnDay (boundary 05:00)', () {
    final feb23 = DateTime(2026, 2, 23, 5);

    test('daytime entry lands on the same calendar date', () {
      expect(placeOnDay('08:30', feb23, 5), DateTime(2026, 2, 23, 8, 30));
    });

    test('after-midnight entry lands on the next calendar date', () {
      expect(placeOnDay('02:00', feb23, 5), DateTime(2026, 2, 24, 2));
    });

    test('exactly at the boundary is the start of the same day', () {
      expect(placeOnDay('05:00', feb23, 5), DateTime(2026, 2, 23, 5));
    });

    test('one minute before the boundary is the end of the day', () {
      expect(placeOnDay('04:59', feb23, 5), DateTime(2026, 2, 24, 4, 59));
    });

    test('next-date placement rolls over the month', () {
      expect(
        placeOnDay('02:00', DateTime(2026, 1, 31, 5), 5),
        DateTime(2026, 2, 1, 2),
      );
    });
  });

  group('placeOnDay (custom boundary 03:00)', () {
    final feb23 = DateTime(2026, 2, 23, 3);

    test('04:00 is after the boundary → same date', () {
      expect(placeOnDay('04:00', feb23, 3), DateTime(2026, 2, 23, 4));
    });

    test('02:00 is before the boundary → next date', () {
      expect(placeOnDay('02:00', feb23, 3), DateTime(2026, 2, 24, 2));
    });
  });

  test('keeps the wall-clock time on a DST-change date', () {
    // 2026-03-29 is the EU spring-forward date. Asserting on the fields (not on
    // a precomputed instant) keeps this test valid in any machine timezone.
    final placed = placeOnDay('08:30', DateTime(2026, 3, 29, 5), 5);
    expect(placed.day, 29);
    expect(placed.hour, 8);
    expect(placed.minute, 30);
  });
}
