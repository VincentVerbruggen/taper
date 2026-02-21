// Day boundary utilities for "today" calculations.
//
// Taper uses 5:00 AM as the day boundary instead of midnight, so late-night
// doses (e.g., caffeine at 1 AM) count as the "previous" day. This matches
// how most people think about their day — 3 AM still feels like "tonight,"
// not "tomorrow morning."
//
// Like setting a custom "day start" in a time-tracking app, or
// Carbon::setTestNow() shifting what "today" means.

/// Returns the most recent day boundary (default 5:00 AM) before [dt].
///
/// If [dt] is at or after the boundary hour, returns today's boundary.
/// If [dt] is before the boundary hour (e.g., 3 AM), rolls back to
/// yesterday's boundary — because 3 AM "feels like" the previous day.
///
/// Examples (with default boundaryHour = 5):
///   7:00 AM Feb 21 → 5:00 AM Feb 21  (after boundary, same day)
///   3:00 AM Feb 21 → 5:00 AM Feb 20  (before boundary, previous day)
///   5:00 AM Feb 21 → 5:00 AM Feb 21  (exactly at boundary, same day)
///   midnight Feb 21 → 5:00 AM Feb 20  (before boundary, previous day)
DateTime dayBoundary(DateTime dt, {int boundaryHour = 5}) {
  // If we're past (or at) the boundary hour, the day started today at boundaryHour.
  // If we're before it, the day started yesterday at boundaryHour.
  // Like: $boundary = $dt->hour >= 5 ? $dt->startOfDay()->setHour(5) : $dt->subDay()->setHour(5)
  if (dt.hour >= boundaryHour) {
    return DateTime(dt.year, dt.month, dt.day, boundaryHour);
  } else {
    // Subtract one day. DateTime handles month/year rollover automatically.
    // Like Carbon::subDay() — Feb 1 at 3 AM → Jan 31 at 5 AM.
    final yesterday = dt.subtract(const Duration(days: 1));
    return DateTime(yesterday.year, yesterday.month, yesterday.day, boundaryHour);
  }
}

/// Returns the next day boundary after [dt].
///
/// Simply adds 24 hours to the current day boundary.
/// Used to define the end of the "today" window for queries.
///
/// Examples:
///   dayBoundary(7 AM Feb 21) = 5 AM Feb 21 → nextDayBoundary = 5 AM Feb 22
///   dayBoundary(3 AM Feb 21) = 5 AM Feb 20 → nextDayBoundary = 5 AM Feb 21
DateTime nextDayBoundary(DateTime dt, {int boundaryHour = 5}) {
  final current = dayBoundary(dt, boundaryHour: boundaryHour);
  // Add exactly 24 hours. DateTime constructor handles overflow.
  return DateTime(current.year, current.month, current.day + 1, boundaryHour);
}
