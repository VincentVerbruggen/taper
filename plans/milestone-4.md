# Milestone 4: Dashboard — Substance Cards & Decay

## Context

The dashboard is currently a placeholder ("coming soon"). Now that substances have `halfLifeHours`, `unit`, and `color` fields (Milestone 3), we can build the core feature: cards showing how much of each substance is still active in the user's system, with decay curves.

## Key Decisions

- **Day boundary**: "Today" starts at 5:00 AM, not midnight. Late-night doses count as the previous day. A simple top-level function, not a class.
- **DecayCalculator**: Pure static methods — no state, no DB access. Unit-testable math only.
- **Per-card providers**: `StreamProvider.family<SubstanceCardData, int>` keyed by substance ID. Each card loads independently (staggered).
- **Substances without half-life** (e.g., Water): Still show a card with "500ml today" but no decay curve and no "active" stat.
- **"Add Dose" from card**: `Navigator.push` to a new `LogDoseScreen` — avoids cross-tab state complexity.
- **"Repeat Last"**: Inserts immediately, shows snackbar with undo (deletes by ID).
- **Substance Log Screen**: Simple `_daysLoaded` counter (starts at 3, +3 on scroll). Uses `StreamBuilder` directly for the scoped stream.
- **`DateTime.now()` staleness**: The provider recalculates when dose streams emit. Active amount may be slightly stale between events — acceptable for MVP. Periodic refresh can be added later.

## New File Structure

```
lib/
├── utils/
│   ├── day_boundary.dart              # dayBoundary() + nextDayBoundary()
│   └── decay_calculator.dart          # DecayCalculator static methods
└── screens/
    └── dashboard/
        ├── substance_log_screen.dart  # Full dose history per substance
        └── widgets/
            ├── substance_card.dart    # Card widget (stats + chart + toolbar)
            └── decay_curve_chart.dart # Mini fl_chart LineChart
test/
├── utils/
│   ├── day_boundary_test.dart
│   └── decay_calculator_test.dart
├── dashboard_screen_test.dart
└── substance_log_screen_test.dart
```

## Implementation Steps

### Step 1: Day Boundary Utility

**New file: `lib/utils/day_boundary.dart`**

Two top-level functions:
- `DateTime dayBoundary(DateTime dt, {int boundaryHour = 5})` — returns most recent 5:00 AM
- `DateTime nextDayBoundary(DateTime dt, {int boundaryHour = 5})` — returns next 5:00 AM

Logic: if `dt.hour < boundaryHour`, roll back to yesterday's boundary.

**New file: `test/utils/day_boundary_test.dart`** — pure unit tests:
- 7am → same day 5am
- 3am → previous day 5am
- Exactly 5:00am → same day 5am
- Midnight → previous day 5am
- `nextDayBoundary` = boundary + 24h

### Step 2: Decay Calculator

**New file: `lib/utils/decay_calculator.dart`**

Static methods on `DecayCalculator`:

```
activeDoseAt(amount, loggedAt, halfLifeHours, queryTime) → double
  Formula: amount × 0.5^(hoursElapsed / halfLifeHours)
  Returns 0 if dose is in future or beyond 5 half-lives

totalActiveAt(doses, halfLifeHours, queryTime) → double
  Sums activeDoseAt for each dose

generateCurve(doses, halfLifeHours, startTime, endTime, {interval: 5min})
  → List<({DateTime time, double amount})>
  Samples totalActiveAt every 5 minutes for chart data

totalRawAmount(doses) → double
  Simple sum of amounts (no decay)
```

**New file: `test/utils/decay_calculator_test.dart`** — pure unit tests:
- At t=0: active == original amount
- At t=halfLife: active ≈ amount/2
- At t=2×halfLife: active ≈ amount/4
- Dose in future → 0
- Beyond 5 half-lives → 0
- Multiple doses sum correctly
- generateCurve point count and values
- Empty dose list → 0

### Step 3: Database Query Methods

**Modified: `lib/data/database.dart`** — add 3 methods:

```
watchDosesSince(substanceId, since) → Stream<List<DoseLog>>
  Doses for one substance from `since` onward, ordered by loggedAt

watchLastDose(substanceId) → Stream<DoseLog?>
  Most recent dose for "Repeat Last" button

watchDosesBetween(substanceId, from, to) → Stream<List<DoseLog>>
  Doses in a date range, for substance log screen
```

Test inline by running existing + new tests.

### Step 4: Dashboard Provider

**Modified: `lib/providers/database_providers.dart`**

Add `SubstanceCardData` class:
```
SubstanceCardData {
  substance: Substance
  activeAmount: double       // Decayed amount at now
  totalToday: double         // Raw sum since day boundary
  curvePoints: List<({DateTime time, double amount})>
  lastDose: DoseLog?         // For "Repeat Last"
}
```

Add `substanceCardDataProvider = StreamProvider.family<SubstanceCardData, int>`:
- Watches substance by ID
- Computes dose query window: `dayBoundary - 5×halfLife` (to capture still-decaying old doses)
- Watches doses since that window
- Runs DecayCalculator to produce all card data
- For substances without half-life: activeAmount=0, curvePoints=[], totalToday from day boundary

### Step 5: Dashboard Screen

**Modified: `lib/screens/dashboard_screen.dart`**

Replace placeholder with `ConsumerWidget`:
- Watch `visibleSubstancesProvider`
- Render `ListView.builder` with one `SubstanceCard(substanceId:)` per substance
- Empty state: "No visible substances" message

### Step 6: Substance Card Widget

**New file: `lib/screens/dashboard/widgets/substance_card.dart`**

`SubstanceCard extends ConsumerWidget`:
- Watches `substanceCardDataProvider(substanceId)`
- Loading state: shimmer skeleton (colored container placeholders)
- Loaded state:
    - Left border accent in substance color
    - Title: substance name
    - Stats: "42mg active / 180mg today" (or just "500ml today" if no half-life)
    - Mini chart (only if curvePoints not empty)
    - Toolbar row: Repeat Last (hidden if no lastDose), Add Dose, View Log

**Repeat Last**: `async` — captures inserted ID from `insertDoseLog`, shows SnackBar with Undo that calls `deleteDoseLog(id)`.

**Add Dose**: `Navigator.push` to `LogDoseScreen` (for now without pre-fill — simplest MVP).

**View Log**: `Navigator.push` to `SubstanceLogScreen(substance:)`.

### Step 7: Decay Curve Chart

**New file: `lib/screens/dashboard/widgets/decay_curve_chart.dart`**

`DecayCurveChart extends StatelessWidget`:
- Takes `curvePoints` + `color`
- Converts to `FlSpot(hoursFromStart, amount)`
- fl_chart `LineChart` with:
    - Single `LineChartBarData`: curved line, substance color, no dots
    - `belowBarData`: translucent area fill
    - `ExtraLinesData` with a dashed `VerticalLine` at "now" position
    - `FlTitlesData(show: false)`, `FlBorderData(show: false)`, `FlGridData(show: false)` — mini chart, no clutter
    - `LineTouchData(enabled: false)` — no touch interactions on mini chart

### Step 8: Substance Log Screen

**New file: `lib/screens/dashboard/substance_log_screen.dart`**

`SubstanceLogScreen extends ConsumerStatefulWidget`:
- Local state: `_daysLoaded = 3`
- AppBar with substance name
- `StreamBuilder` watching `db.watchDosesBetween(id, startBoundary, endBoundary)`
- Groups doses by day boundary into `Map<DateTime, List<DoseLog>>`
- Renders day groups: header (date + daily total) + individual dose entries
- Each entry: amount + unit + time, delete button, tap to edit
- `ScrollNotification` listener: when `extentAfter < 200`, increment `_daysLoaded += 3`

### Step 9: Tests

**`test/dashboard_screen_test.dart`**:
- Shows cards for visible substances
- Empty state when no visible substances
- Card shows substance name and stats
- Card hides "Repeat Last" when no doses exist

**`test/substance_log_screen_test.dart`**:
- Shows doses grouped by day
- Daily total shown in header
- Delete removes dose from list
- Tap navigates to edit screen

All widget tests use: `createTestDatabase()`, `pumpAndWait()`, cleanup ordering, `--timeout 10s`.

### Step 10: Run full suite + update docs

- `flutter analyze` — no warnings
- `flutter test --timeout 10s` — all pass
- Update `CLAUDE.md` project structure + current state

## Files to Modify

| File | What changes |
|------|-------------|
| `lib/utils/day_boundary.dart` | **NEW** — day boundary utility |
| `lib/utils/decay_calculator.dart` | **NEW** — decay math |
| `lib/data/database.dart` | Add 3 query methods |
| `lib/providers/database_providers.dart` | Add SubstanceCardData + family provider |
| `lib/screens/dashboard_screen.dart` | Replace placeholder with card list |
| `lib/screens/dashboard/widgets/substance_card.dart` | **NEW** — card widget |
| `lib/screens/dashboard/widgets/decay_curve_chart.dart` | **NEW** — mini chart |
| `lib/screens/dashboard/substance_log_screen.dart` | **NEW** — per-substance log |
| `test/utils/day_boundary_test.dart` | **NEW** |
| `test/utils/decay_calculator_test.dart` | **NEW** |
| `test/dashboard_screen_test.dart` | **NEW** |
| `test/substance_log_screen_test.dart` | **NEW** |
| `CLAUDE.md` | Update structure + current state |

## Verification

1. `flutter analyze` — no warnings
2. `flutter test --timeout 10s` — all tests pass (old + new)
3. Manual: dashboard shows substance cards with stats
4. Manual: Caffeine card shows decay curve, Water card shows just total
5. Manual: "Repeat Last" logs a dose + shows undo snackbar
6. Manual: "View Log" navigates to substance history with day grouping
