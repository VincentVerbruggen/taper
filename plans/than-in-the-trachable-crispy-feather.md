# Fix the trackable "View Log" day-graph: rounded tooltips + correct time axis

## Context

Tapping **View Log** on a dashboard trackable card (`trackable_card.dart:142`/`:634` →
`TrackableLogScreen`) opens a per-trackable **day view**: one selected day, a decay
curve, date navigation, and a daily total. The decay chart lives in
`_buildDayGraph()` in `lib/screens/dashboard/trackable_log_screen.dart` (line 199).

Two problems on that chart, both reported by the user:

1. **Touch tooltip shows raw, unrounded numbers.** The `LineChart` there has **no**
   `lineTouchData`, so fl_chart renders its *default* tooltip, which prints the raw
   `spot.y` at full precision (e.g. `123.456789`). The user wants ~3 significant
   digits (`100`, `10`, `1`, `1.23`).

2. **Time axis starts at `00:00` instead of the start-of-day time.** The chart's
   x-axis is *hours since the day boundary* — `x = p.time.difference(selectedBoundary)`
   (line 259), and `selectedBoundary` is the configurable boundary (default **05:00**).
   So `x = 0` is really 05:00 wall-clock. But the bottom-label formatter naively does
   `'${value.toInt()}:00'` (line 334-339), printing `00:00` at `x=0`, `06:00` at `x=6`,
   etc. — the labels are shifted off real clock time.

The sibling chart `trackable_card.dart` (`_buildDualModeChart`, lines 402-439 tooltip,
448-457 time helpers) **already solves both correctly**. This change brings the day-view
chart in line with it. User decision (via question): the axis should **start exactly at
the boundary** — label every 6h from the boundary, converted to wall-clock:
`05:00 · 11:00 · 17:00 · 23:00 · 05:00`.

## Changes — all in `lib/screens/dashboard/trackable_log_screen.dart`, `_buildDayGraph()`

### 1. Fix the bottom-axis labels (line ~333-345)

In the `bottomTitles` `getTitlesWidget`, convert the axis value (hours-from-boundary)
into a real wall-clock time before formatting. Keep `interval: 6` so ticks land at
0/6/12/18/24 h → 05:00 / 11:00 / 17:00 / 23:00 / 05:00.

```dart
getTitlesWidget: (value, meta) {
  final hoursFromBoundary = value.toInt();
  if (hoursFromBoundary < 0 || hoursFromBoundary > 24) {
    return const SizedBox.shrink();
  }
  // x = 0 is the day boundary (e.g. 05:00), not midnight — convert the
  // axis value (hours since the boundary) into real wall-clock time so the
  // labels start at the start-of-day time instead of 00:00.
  final labelTime = selectedBoundary.add(Duration(hours: hoursFromBoundary));
  return Text(
    '${labelTime.hour.toString().padLeft(2, '0')}:00',
    style: TextStyle(color: axisColor.withAlpha(160), fontSize: 10),
  );
},
```

### 2. Add a rounded, clock-time tooltip (inside `LineChartData`, alongside `titlesData`)

Mirror `trackable_card.dart` lines 402-439. Add `lineTouchData` with a custom
`getTooltipItems` that (a) rounds via the existing
`formatWithSignificantDigits(spot.y)` (already imported, used at line 359 for the Y
axis) and (b) shows the wall-clock time of the touched point. Distinguish the actual
line (`barIndex 0`) from the projected line (`barIndex 1`, only present when
`data.hasPlannedDoses && projectedSpots.isNotEmpty`).

```dart
lineTouchData: LineTouchData(
  touchTooltipData: LineTouchTooltipData(
    getTooltipColor: (_) =>
        Theme.of(context).colorScheme.surfaceContainerHighest,
    getTooltipItems: (spots) {
      // projected line is the 2nd bar when planned doses exist
      final projectedIndex =
          (data.hasPlannedDoses && projectedSpots.isNotEmpty) ? 1 : null;
      return spots.map((spot) {
        // spot.x is hours since the boundary — same mapping as the axis.
        final spotTime =
            selectedBoundary.add(Duration(minutes: (spot.x * 60).round()));
        final timeStr =
            '${spotTime.hour.toString().padLeft(2, '0')}:${spotTime.minute.toString().padLeft(2, '0')}';
        final amount = formatWithSignificantDigits(spot.y); // 3 sig digits
        final isProjected = spot.barIndex == projectedIndex;
        final label = isProjected ? 'Projected' : 'Amount';
        return LineTooltipItem(
          '$timeStr\n$label: $amount ${widget.trackable.unit}',
          TextStyle(
            color: isProjected ? trackableColor.withAlpha(170) : trackableColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        );
      }).toList();
    },
  ),
),
```

**Reused, no new utilities:** `formatWithSignificantDigits`
(`lib/utils/significant_digits_formatter.dart`, default 3 sig digits) and the
in-scope `selectedBoundary`, `trackableColor`, `projectedSpots`, `data`.

## Tests

Extend `test/trackable_log_screen_test.dart` (follow the existing setup + the
Drift/Riverpod cleanup ordering noted in project memory — dispose widget tree
before closing the DB; use bounded pumps, not `pumpAndSettle`). Use a fixed clock
and default boundary hour (5) so the mapping is deterministic:

- **Axis label**: after logging a dose so the chart renders, assert the boundary
  label is present and the naive one is gone — `expect(find.text('05:00'), findsWidgets)`
  and `expect(find.text('00:00'), findsNothing)`.

(The touch tooltip is gesture-driven and awkward to assert in a widget test; the
axis-label test plus `flutter analyze` covers the regression. If a tooltip test is
wanted, factor the `spot.y` → string mapping is already unit-covered by
`test/utils/` for `formatWithSignificantDigits`.)

## Verification

1. `flutter analyze` — no new warnings.
2. `flutter test --timeout 10s --fail-fast test/trackable_log_screen_test.dart`
3. Manual (`flutter run`): open a trackable → **View Log**. Confirm the x-axis reads
   `05:00 · 11:00 · 17:00 · 23:00 · 05:00` (or matching the configured boundary hour),
   and touching the curve shows e.g. `08:30 / Amount: 123 mg` with a rounded number.
