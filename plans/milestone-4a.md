# Dashboard & Substance Screen Polish

## Context

The dashboard was just implemented (Milestone 4) but needs several UI improvements:
1. Card list starts under the status bar — needs a header + safe area padding
2. Substance log screen has no quick-add — needs a FAB with a popup dialog
3. Substances have no user-controlled ordering — needs drag-to-reorder + a new DB column
4. Card layout is too verbose — move stats to the title row: `| Caffeine   42 / 180 mg |`
5. Charts have no axes and no touch interaction — need time labels + scrubbing/tooltip

Seeder is already correct (Caffeine has 5.0h half-life, Alcohol has 4.0h, Water stays null; units are mg/ml/ml).

## Steps

### Step 1: Database — Add `sortOrder` column (v5 migration)

**File: `lib/data/database.dart`**

- Add `IntColumn get sortOrder => integer().withDefault(const Constant(0))()` to `Substances` table
- Bump `schemaVersion` to 5
- Add v5 migration: `m.addColumn(substances, substances.sortOrder)`, then set each existing row's `sortOrder = id` (preserves insertion order)
- Update `onCreate` seeder: add `sortOrder: const Value(1/2/3)` to the 3 seeded substances
- Change `watchAllSubstances()` to order by `sortOrder` instead of `name`
- Change `watchVisibleSubstances()` to order by `sortOrder` instead of `name`
- Update `insertSubstance()` to set `sortOrder = max(sortOrder) + 1`
- Add `reorderSubstances(List<int> orderedIds)` method — transaction that writes `sortOrder = i` for each ID
- Run `dart run build_runner build --delete-conflicting-outputs`

### Step 2: Dashboard screen — Header + safe area

**File: `lib/screens/dashboard_screen.dart`**

- Wrap output in `SafeArea(bottom: false)` to clear the status bar
- Make the first item in `ListView.builder` a "Dashboard" heading (same `headlineMedium` style as "Log Dose" heading)
- Adjust `itemCount: substances.length + 1`, shift card indices by 1

### Step 3: Substance card — Compact title row with stats

**File: `lib/screens/dashboard/widgets/substance_card.dart`**

Replace the separate title + stats lines with a single `Row`:
```
| Caffeine     42 / 180 mg |   (with half-life: active / total unit)
| Water            500 ml  |   (without half-life: total unit)
```

- Title left (Flexible, ellipsis overflow), stats right
- `crossAxisAlignment: CrossAxisAlignment.baseline` for aligned text
- Update `_buildStatsText()`: `"$active / $total $unit"` or `"$total $unit"`
- Remove the SizedBox(height: 4) and old stats Text widget

### Step 4: Decay curve chart — Axes + scrubbing

**File: `lib/screens/dashboard/widgets/decay_curve_chart.dart`**

- Enable `FlTitlesData` with:
  - Bottom axis: time labels every 4 hours ("5a", "9a", "1p", "5p", "9p", "1a")
  - Left axis: amount labels (auto-scaled by fl_chart, show 2-3 values)
  - Hide top and right titles
- Enable `LineTouchData`:
  - `touchTooltipData`: show amount + time at touched position
  - `getTouchedSpotIndicator`: vertical line + dot at touch point
  - `handleBuiltInTouches: true`
- Keep the "now" dashed vertical line
- Increase chart height slightly (100 → 120) to fit the bottom axis labels
- Pass `startTime` (DateTime) as a new parameter so we can format X-axis labels as clock times

### Step 5: Substance log screen — FAB + quick-add dialog

**File: `lib/screens/dashboard/substance_log_screen.dart`**

- Add `floatingActionButton` to the Scaffold
- FAB opens `showDialog` with an `AlertDialog`:
  - Title: "Log {substance.name}"
  - Content: amount TextField (numeric, autofocus, substance unit as suffix)
  - Actions: Cancel + Log (disabled until valid amount)
  - `onSubmitted` on TextField for keyboard submit
- On submit: `insertDoseLog(substanceId, amount, DateTime.now())`, close dialog, show SnackBar
- Add `import 'package:flutter/services.dart'` for `FilteringTextInputFormatter`

### Step 6: Substances screen — Drag-to-reorder

**File: `lib/screens/substances/substances_screen.dart`**

- Move the add form out of the list into a `Column` above the list
- Replace `ListView.builder` with `ReorderableListView.builder`
- Add `key: ValueKey(substance.id)` to each list item
- Add `_onReorder(substances, oldIndex, newIndex)` method:
  - Adjust newIndex (Flutter's quirk: `if (newIndex > oldIndex) newIndex -= 1`)
  - Build reordered ID list, call `db.reorderSubstances(ids)`
- Long-press to drag (default behavior, no extra drag handle needed)

### Step 7: Update tests

**`test/dashboard_screen_test.dart`**:
- Add test: "shows Dashboard header"
- Update stats format assertions: `'active'` → `'/'`, `'500 ml today'` → `'500 ml'`

**`test/substance_log_screen_test.dart`**:
- Add test: "FAB opens quick-add dialog"
- Add test: "quick-add dialog logs dose and closes"

**`test/substances_screen_test.dart`**:
- Verify existing tests still pass with ReorderableListView

### Step 8: Run full suite + analyze

- `flutter analyze` — no warnings
- `flutter test --timeout 10s` — all pass

## Files to Modify

| File | Changes |
|------|---------|
| `lib/data/database.dart` | sortOrder column, v5 migration, reorder method, query ordering |
| `lib/screens/dashboard_screen.dart` | SafeArea + header |
| `lib/screens/dashboard/widgets/substance_card.dart` | Compact title row with stats |
| `lib/screens/dashboard/widgets/decay_curve_chart.dart` | Axes + touch scrubbing |
| `lib/screens/dashboard/substance_log_screen.dart` | FAB + quick-add dialog |
| `lib/screens/substances/substances_screen.dart` | ReorderableListView |
| `test/dashboard_screen_test.dart` | Header test + stats format updates |
| `test/substance_log_screen_test.dart` | FAB tests |

## Verification

1. `flutter analyze` — no warnings
2. `flutter test --timeout 10s` — all pass
3. Dashboard has header below status bar, cards show compact stats
4. Chart shows time axis labels and amount tooltip on touch/scrub
5. Substance log FAB opens dialog, logging a dose updates the list
6. Substances screen: long-press to drag reorder, order reflected in dashboard
