# Milestone 14: Unified Decay Card & Chart Overhaul — Execution Plan

## Context

The dashboard currently has two decay card types: `decay_card` (simple `TrackableCard` in `trackable_card.dart`) and `enhanced_decay_card` (gradient fill, pan/zoom, glow in `enhanced_decay_card.dart`). They're nearly identical in layout and data — both use `trackableCardDataProvider` — but the enhanced version has better visuals. The user wants to:

1. Consolidate into one card type (keep enhanced, drop simple)
2. Add dual viewing modes (decay-focused vs total-focused) with a toggle
3. Add a new threshold type comparing against active/acute amount
4. Extend charts to show previous/next day carry-over, make scrollable/zoomable

This is split into 4 independent steps, each verifiable before moving on.

---

## Step 1: Merge Enhanced into Standard

**Goal:** One card type. The enhanced card becomes the only decay card.

### 1a. Remove `enhancedDecayCard` from enum
**File:** `lib/data/dashboard_widget_type.dart`
- Remove the `enhancedDecayCard` enum value
- In `fromString()`: map both `'decay_card'` AND `'enhanced_decay_card'` → `decayCard` (backward compat for existing DB rows that still say `enhanced_decay_card`)
- Remove from `toDbString()` and `displayName`

### 1b. Promote enhanced card → `TrackableCard`
- **Rename class** `EnhancedDecayCard` → `TrackableCard` inside `enhanced_decay_card.dart`
- **Rename file** `enhanced_decay_card.dart` → `trackable_card.dart` (move/rename)
- **Delete** old `trackable_card.dart` (the simple version)
- **Delete** `decay_curve_chart.dart` (the simple chart widget — only used by the old simple card)
- **Port** the overflow menu (`_buildOverflowMenu`) and title row layout (Expanded + Spacer + menu pinned right) from the old `TrackableCard` into the merged one
- **Remove** the colored left border (`Border(left: BorderSide(...))`) — per earlier user request

### 1c. Update dashboard_screen.dart
**File:** `lib/screens/dashboard_screen.dart`
- Remove `enhancedDecayCard` case from `_buildWidgetCard()` switch — both DB strings resolve to `decayCard` → `TrackableCard`
- Remove `Decay Card (Enhanced)` from the "Add Widget" dialog
- Update imports

### 1d. Update all imports & tests
- `grep` for `enhanced_decay_card`, `EnhancedDecayCard`, `decay_curve_chart`, `DecayCurveChart` across `lib/` and `test/`
- **Rename** `test/enhanced_decay_card_test.dart` → `test/trackable_card_test.dart`
- **Update** `test/dashboard_screen_test.dart` and `test/dashboard_widgets_test.dart`

### Verify
```bash
flutter analyze && flutter test --timeout 10s
```

---

## Step 2: Dual-Mode Chart (Decay Focus / Total Focus)

**Goal:** Toggle between "what's active in my system" and "what I consumed today" on the same card.

### 2a. Pass widget config to card
**File:** `lib/screens/dashboard_screen.dart`
- Currently `_buildWidgetCard()` only passes `trackableId`
- Add `widgetId` and `config` (parsed from the DB `config` column, already exists with default `'{}'`)
- Card reads mode from config: `{"mode": "decay"}` (default) or `{"mode": "total"}`

### 2b. Add toggle button to title row
**File:** `lib/screens/dashboard/widgets/trackable_card.dart`
- Add an `IconButton` between stats and the three-dot menu
- Icon: `Icons.show_chart` (decay) / `Icons.bar_chart` (total) — visually hints at mode
- On tap: flip mode in config JSON, call `db.updateDashboardWidgetConfig(widgetId, newJson)`

### 2c. Implement dual rendering in the chart
**File:** `lib/screens/dashboard/widgets/trackable_card.dart`

**Decay Focus mode (default):**
- Primary line = decay curve (solid, gradient fill, shadow glow) — current behavior
- Y-axis scales to max active amount
- Cumulative line hidden (or subtle dashed secondary)
- Stats text: "42 / 180 mg" (active / total)

**Total Focus mode:**
- Primary line = cumulative staircase (solid, gradient fill, shadow glow)
- Y-axis scales to max cumulative amount
- Decay curve becomes subtle dashed secondary
- Stats text: "180 mg today" (total only, active amount less prominent)

### 2d. Tests
- Test mode toggle changes icon
- Test config persistence round-trip
- Test both chart modes render without errors

### Verify
```bash
flutter analyze && flutter test --timeout 10s
```
Visual: toggle button visible, tapping swaps chart focus, mode persists on re-render.

---

## Step 3: Acute Amount Thresholds

**Goal:** Thresholds that compare against active (in-system) amount, not just daily total.

### 3a. Schema migration
**File:** `lib/data/database.dart`
- Add `comparisonType` column to `Thresholds` table: `text().withDefault(const Constant('daily_total'))`
- Values: `'daily_total'` (existing) or `'active_amount'` (new)
- Increment schema version, migration: `ALTER TABLE thresholds ADD COLUMN comparison_type TEXT NOT NULL DEFAULT 'daily_total'`
- Run `dart run build_runner build --delete-conflicting-outputs`

### 3b. Update threshold CRUD & data flow
**File:** `lib/data/database.dart` — `insertThreshold()`, `updateThreshold()` accept `comparisonType`
**File:** `lib/providers/database_providers.dart` — `TrackableCardData.thresholds` includes `comparisonType`

### 3c. Threshold editor UI
**File:** `lib/screens/trackables/thresholds_screen.dart`
- Add dropdown or segmented button in add/edit dialog: "Daily Total" / "Active Amount"
- Default: Daily Total (backward compat)

### 3d. Chart rendering per mode
**File:** `lib/screens/dashboard/widgets/trackable_card.dart`
- In **Decay Focus** mode: show only `active_amount` thresholds (on the decay curve)
- In **Total Focus** mode: show only `daily_total` thresholds (on the cumulative line)
- Both types always visible in the "other" mode as subtle/muted lines (optional, could skip)

### 3e. Tests
- DB migration test for new column
- Threshold CRUD with comparisonType
- Verify thresholds render in correct mode

### Verify
```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze && flutter test --timeout 10s
```

---

## Step 4: Multi-Day Chart View

**Goal:** Show yesterday's carry-over and tomorrow's projection. Scroll/zoom enabled.

### 4a. Extend data window
**File:** `lib/providers/database_providers.dart`
- Currently calculates curve points for one day boundary period (24h)
- Extend to ~6h before day start (show previous day decay trailing in) and ~6h after day end (show projected decay into tomorrow)
- Reuse existing `DecayCalculator.generateCurve()` / `generateLinearCurve()` — just widen the time range parameters
- Also extend cumulative points for the wider window

### 4b. Update chart x-axis
**File:** `lib/screens/dashboard/widgets/trackable_card.dart`
- X-axis spans ~36h instead of 24h
- Default view (no user zoom) still focuses on today's boundary period
- Use `TransformationController` (like `DailyTotalsCard` already does) to set initial viewport offset
- `FlTransformationConfig` already enables pan/zoom — just ensure scale range works well with wider data

### 4c. Day boundary markers
- Draw faint vertical dashed lines at day boundary times (5 AM today, 5 AM tomorrow)
- Optional: slightly tint the "outside today" regions to visually separate them

### 4d. Tests
- Verify extended curve includes carry-over data from previous day
- Chart renders without errors with wider range

### Verify
```bash
flutter analyze && flutter test --timeout 10s
```
Visual: chart shows decay trailing in from left (yesterday), scrolling right shows projection into tomorrow.

---

## Key Files

| File | Action |
|------|--------|
| `lib/data/dashboard_widget_type.dart` | Remove `enhancedDecayCard` enum value |
| `lib/screens/dashboard/widgets/enhanced_decay_card.dart` | Rename class → `TrackableCard`, rename file → `trackable_card.dart` |
| `lib/screens/dashboard/widgets/trackable_card.dart` | Delete old simple version |
| `lib/screens/dashboard/widgets/decay_curve_chart.dart` | Delete (unused after merge) |
| `lib/screens/dashboard_screen.dart` | Update switch, remove enhanced option from dialog |
| `lib/data/database.dart` | Add `comparisonType` to Thresholds, schema migration |
| `lib/providers/database_providers.dart` | Extend card data for multi-day window + threshold type |
| `lib/screens/trackables/thresholds_screen.dart` | Add comparison type dropdown |
| `test/enhanced_decay_card_test.dart` | Rename → `test/trackable_card_test.dart` |
| `test/dashboard_screen_test.dart` | Update references |
| `test/dashboard_widgets_test.dart` | Update type strings |

## Existing Code to Reuse

- **`trackableCardDataProvider`** in `database_providers.dart` — already provides both curve + cumulative data
- **`FlTransformationConfig`** — already in enhanced card for horizontal pan/zoom
- **`updateDashboardWidgetConfig()`** in `database.dart` — exists, ready for mode storage
- **`DecayCalculator.generateCurve()` / `generateLinearCurve()`** — widen time params for multi-day
- **`_buildOverflowMenu()`** from current `TrackableCard` — port to merged card
- **`TransformationController`** pattern from `DailyTotalsCard` — reuse for initial viewport positioning
