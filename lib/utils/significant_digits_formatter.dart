import 'dart:math';

/// Format numeric values with a fixed number of significant digits.
///
/// Why this exists:
/// - Graphs can span large ranges (for example 100 -> 0.01).
/// - Fixed integer rounding (`toStringAsFixed(0)`) hides low values as `0`.
/// - Significant-digit formatting keeps labels compact and readable at any scale.
String formatWithSignificantDigits(
  double value, {
  int significantDigits = 3,
  int maxFractionDigits = 10,
}) {
  if (!value.isFinite) {
    return value.toString();
  }

  if (value == 0) {
    return '0';
  }

  // Guard against accidental invalid configuration from callers.
  if (significantDigits < 1) {
    significantDigits = 1;
  }

  final absoluteValue = value.abs();
  final orderOfMagnitude = (log(absoluteValue) / ln10).floor();
  var fractionDigits = significantDigits - orderOfMagnitude - 1;

  // For large numbers, we round to tens/hundreds/etc so we still keep the
  // same significant-digit intent without showing fractional noise.
  if (fractionDigits < 0) {
    final roundingFactor = pow(10, -fractionDigits).toDouble();
    final rounded = (value / roundingFactor).roundToDouble() * roundingFactor;
    return rounded.toStringAsFixed(0);
  }

  fractionDigits = fractionDigits.clamp(0, maxFractionDigits);
  final fixed = value.toStringAsFixed(fractionDigits);
  return _trimTrailingZeros(fixed);
}

String _trimTrailingZeros(String value) {
  if (!value.contains('.')) {
    return value;
  }

  final trimmed = value.replaceFirst(RegExp(r'\.?0+$'), '');
  // Rounded negative values can produce "-0", which reads oddly in UI.
  return trimmed == '-0' ? '0' : trimmed;
}
