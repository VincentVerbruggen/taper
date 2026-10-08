// Time helpers for day templates.
//
// A template stores only the clock time of each entry ("08:30"), not a date.
// The date is decided when the template is applied to a day, because the app's
// "day" runs from the boundary hour (default 05:00) to the next boundary — so a
// "02:00" entry belongs to the night AFTER the day's calendar date.
//
// Pure Dart, no Flutter imports — like a plain PHP helper class with no
// framework dependencies, so it can be unit-tested in isolation.

/// Formats [t] as a zero-padded 24h "HH:MM" string. Seconds are dropped.
///
/// Like Carbon's `$dt->format('H:i')`.
String toTemplateTime(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Places a template time ("HH:MM") onto the day that starts at [dayBoundary].
///
/// Times before [boundaryHour] belong to the night after the day's calendar
/// date, so they land on date + 1. With a 05:00 boundary on Feb 23:
///   "08:30" → Feb 23 08:30
///   "02:00" → Feb 24 02:00 (still part of "Feb 23" in the app)
///
/// [boundaryHour] is passed explicitly instead of reading `dayBoundary.hour`:
/// on a DST-forward day a boundary like 02:00 doesn't exist and Dart shifts it
/// to 03:00, which would misclassify entries between the two.
///
/// The timestamp is rebuilt with the DateTime constructor rather than adding a
/// Duration: the constructor normalises month overflow (Jan 31 + 1 → Feb 1) and
/// keeps the wall-clock time on DST-change days, where "one day" isn't 24h.
DateTime placeOnDay(String hhmm, DateTime dayBoundary, int boundaryHour) {
  // Stored values are always written by toTemplateTime, so plain int.parse is
  // safe — no defensive tryParse needed for data we produced ourselves.
  final parts = hhmm.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);

  final dayOffset = hour < boundaryHour ? 1 : 0;
  return DateTime(
    dayBoundary.year,
    dayBoundary.month,
    dayBoundary.day + dayOffset,
    hour,
    minute,
  );
}
