import 'package:flutter_test/flutter_test.dart';
import 'package:taper/utils/validation.dart';

void main() {
  // --- Tests for numericFieldErrorAllowZero ---
  // This is the variant used on dose amount fields where 0 = "I skipped this
  // dose." It's like a nullable boolean: null (no log entry) vs 0 (explicitly
  // skipped). The original numericFieldError still rejects zero for fields like
  // presets and thresholds where 0 makes no sense.

  group('numericFieldErrorAllowZero', () {
    test('returns null for empty string', () {
      // Empty = "user hasn't typed anything yet" — no error shown.
      // Like leaving a nullable field blank in a Laravel form.
      expect(numericFieldErrorAllowZero(''), null);
      expect(numericFieldErrorAllowZero('  '), null);
    });

    test('returns null for zero', () {
      // Zero is the whole point of this variant — it means "skipped."
      expect(numericFieldErrorAllowZero('0'), null);
      expect(numericFieldErrorAllowZero('0.0'), null);
    });

    test('returns null for positive numbers', () {
      // Normal dose amounts should pass just like the original validator.
      expect(numericFieldErrorAllowZero('42'), null);
      expect(numericFieldErrorAllowZero('3.14'), null);
    });

    test('returns error for invalid input', () {
      // Edge cases that slip past FilteringTextInputFormatter —
      // double.tryParse returns null for these, so we catch them here.
      expect(numericFieldErrorAllowZero('.'), isNotNull);
      expect(numericFieldErrorAllowZero('1.2.3'), isNotNull);
      expect(numericFieldErrorAllowZero('abc'), isNotNull);
    });

    test('returns error for negative numbers', () {
      // Negative doses make no sense — you can't un-drink coffee.
      expect(numericFieldErrorAllowZero('-1'), isNotNull);
    });
  });

  // --- Regression tests for numericFieldError ---
  // Make sure the original validator still rejects zero. If someone
  // accidentally swaps numericFieldError for numericFieldErrorAllowZero
  // on a preset/threshold field, these tests will catch it.

  group('numericFieldError', () {
    test('rejects zero', () {
      // Zero is invalid for presets, thresholds, half-life, etc.
      expect(numericFieldError('0'), isNotNull);
      expect(numericFieldError('0.0'), isNotNull);
    });

    test('accepts positive numbers', () {
      expect(numericFieldError('1'), null);
      expect(numericFieldError('3.14'), null);
    });
  });
}
