import 'package:flutter_test/flutter_test.dart';
import 'package:taper/utils/significant_digits_formatter.dart';

void main() {
  group('formatWithSignificantDigits', () {
    test('keeps whole-number values compact at higher ranges', () {
      // 100 already has exactly 3 significant digits, so it stays "100".
      expect(formatWithSignificantDigits(100), '100');
      // 999.6 rounds to 3 significant digits -> 1000.
      expect(formatWithSignificantDigits(999.6), '1000');
    });

    test('rounds decimal values to 3 significant digits', () {
      // 12.345 -> 12.3 (3 significant digits).
      expect(formatWithSignificantDigits(12.345), '12.3');
      // 1.2345 -> 1.23.
      expect(formatWithSignificantDigits(1.2345), '1.23');
    });

    test('preserves small values instead of flattening to zero', () {
      // These cases are the reason this formatter exists for chart labels.
      expect(formatWithSignificantDigits(0.12345), '0.123');
      expect(formatWithSignificantDigits(0.012345), '0.0123');
      expect(formatWithSignificantDigits(0.01004), '0.01');
    });

    test('handles zero and negative values safely', () {
      expect(formatWithSignificantDigits(0), '0');
      expect(formatWithSignificantDigits(-0.012345), '-0.0123');
      // Very small negatives should not render as "-0".
      expect(formatWithSignificantDigits(-0.00004), '-0.00004');
    });

    test('passes through non-finite values', () {
      expect(formatWithSignificantDigits(double.infinity), 'Infinity');
      expect(formatWithSignificantDigits(double.negativeInfinity), '-Infinity');
      expect(formatWithSignificantDigits(double.nan), 'NaN');
    });
  });
}
