# Plan: Customizable Dashboard (Milestone 10)

## Context

The dashboard currently auto-generates one card per visible trackable using `visibleTrackablesProvider`. This ties dashboard layout to the `isVisible` flag, which also controls log form dropdown visibility — two unrelated concerns. There's no way to add different views of the same trackable (e.g., decay curve AND taper progress side by side), reorder cards independently of trackable sort order, or remove a card without hiding the trackable from the log form.

This milestone decouples "what's on the dashboard" from "what trackables exist" by introducing a `DashboardWidgets` table. A trackable is a data source; a dashboard widget is a view of that data.

**Scope:** 2 widget types (`decay_card` + `taper_progress`), edit mode in the dashboard header, no chart style changes.

## Steps

### Step 1: DashboardWidgets table + migration (v12 → v13)

**File:** `lib/data/database.dart`

Add `DashboardWidgets` table class:
```
id: int (PK)
type: String ('decay_card' | 'taper_progress')
trackableId: int? (nullable FK → trackables, cascade delete)
sortOrder: int (default 0)
config: String (default '{}', JSON blob for per-widget settings)
```

Add to `@DriftDatabase(tables: [..., DashboardWidgets])`. Bump schema to 13.

**Migration (`if (from < 13)`):**
1. `m.createTable(dashboardWidgets)`
2. For each visible trackable: insert a `decay_card` widget (copy sortOrder, move `showCumulativeLine` into config JSON)
3. For each visible trackable with an active taper plan: also insert a `taper_progress` widget (sortOrder after all cards)

**onCreate seeder update:** After inserting Caffeine/Water/Alcohol, also insert `decay_card` widgets for Caffeine (sortOrder 1) and Water (sortOrder 2). Alcohol is hidden, no widget.

Run codegen: `dart run build_runner build --delete-conflicting-outputs`

### Step 2: Database CRUD methods for dashboard widgets

**File:** `lib/data/database.dart`

Add to `AppDatabase`:
- `watchDashboardWidgets()` → `Stream<List<DashboardWidget>>` ordered by sortOrder
- `insertDashboardWidget(type, {trackableId, config})` → auto-assigns sortOrder = max + 1
- `deleteDashboardWidget(id)`
- `reorderDashboardWidgets(List<int> orderedIds)` → transaction, same pattern as `reorderTrackables()`
- `updateDashboardWidgetConfig(id, config)`

**Also modify `insertTrackable()`:** After inserting the trackable, call `insertDashboardWidget('decay_card', trackableId: trackableId)` so new trackables auto-appear on the dashboard.

### Step 3: DashboardWidgetType enum + provider

**New file:** `lib/data/dashboard_widget_type.dart`
- Enum: `decayCard`, `taperProgress`
- `fromString(String)` → parses DB value (`'decay_card'` / `'taper_progress'`)
- `toDbString()` → converts back
- `displayName` getter → human-readable labels for the add dialog

**File:** `lib/providers/database_providers.dart`
- Add `dashboardWidgetsProvider = StreamProvider<List<DashboardWidget>>` wrapping `db.watchDashboardWidgets()`

### Step 4: Inline TaperProgressCard widget

**New file:** `lib/screens/dashboard/widgets/taper_progress_card.dart`

A `ConsumerWidget` that renders the taper progress chart inline as a dashboard card. Adapts chart logic from `TaperProgressScreen` but:
- Wrapped in a `Card` with the trackable's colored left border (matching `TrackableCard` styling)
- Chart height 200px (not 300px)
- No `InteractiveViewer` (card is too small for zoom/pan)
- No `AppBar` / `Scaffold` — just the card content
- Tapping the card pushes the full `TaperProgressScreen`
- Handles the case where the active plan disappears (e.g., user deletes it) — show empty state

Constructor: `TaperProgressCard({required int trackableId})`

Watches: `trackablesProvider` (for trackable data), `activeTaperPlanProvider(trackableId)` (for the plan), `dayBoundaryHourProvider`, `databaseProvider` (for dose streams).

### Step 5: Rewire DashboardScreen to use dashboard widgets

**File:** `lib/screens/dashboard_screen.dart`

Replace `ref.watch(visibleTrackablesProvider)` with `ref.watch(dashboardWidgetsProvider)`.

The `ListView.builder` switches on `DashboardWidgetType.fromString(widget.type)`:
- `decayCard` → `TrackableCard(trackableId: widget.trackableId!)`
- `taperProgress` → `TaperProgressCard(trackableId: widget.trackableId!)`

Update empty state text: "No dashboard widgets. Tap the edit icon to add one."

At this point the dashboard renders identically to before (migration seeded the same layout), but reads from the new table.

### Step 6: Edit mode (toggle, reorder, delete)

**File:** `lib/screens/dashboard_screen.dart`

Convert from `ConsumerWidget` to `ConsumerStatefulWidget`. Add `_isEditMode` bool (local state — resets naturally, no provider needed).

**Header change:** Add a pencil/check icon button to the date nav row that toggles `_isEditMode`.

**Edit mode rendering:** Replace `ListView.builder` with `ReorderableListView.builder`:
- Each item shows a simplified label (drag handle + colored dot + trackable name + type label + delete X button) instead of the full card. Full cards are expensive and their interactive buttons conflict with drag gestures.
- "Add Widget" button as the last item
- `onReorder` → call `db.reorderDashboardWidgets(reorderedIds)`
- Delete button → call `db.deleteDashboardWidget(widget.id)`

**Normal mode:** Unchanged `ListView.builder` from Step 5.

### Step 7: "Add Widget" dialog

**File:** `lib/screens/dashboard_screen.dart` (method on the StatefulWidget)

Two-step dialog:
1. Pick widget type (SimpleDialog with `decay_card` and `taper_progress` options)
2. Pick a trackable (SimpleDialog listing trackables with color dots)
   - For `taper_progress`: filter to only trackables with an active taper plan. If none, show a SnackBar and bail.

Insert via `db.insertDashboardWidget(type.toDbString(), trackableId: selected.id)`.

### Step 8: Tests

**Update:** `test/dashboard_screen_test.dart`
- Tests still work because `onCreate` now seeds dashboard widgets for Caffeine + Water
- "empty state" test: delete dashboard widgets instead of hiding trackables
- Add: edit mode toggle shows/hides drag handles
- Add: add widget dialog shows type options

**New:** `test/dashboard_widgets_test.dart` (database-level)
- Fresh DB seeds Caffeine + Water widgets
- CRUD: insert, delete, reorder, update config
- Auto-add on trackable creation
- Cascade delete: delete trackable → widgets gone

**New:** `test/taper_progress_card_test.dart` (widget test)
- Renders plan summary and chart when active plan exists
- Shows empty/fallback state when no active plan
- Tapping navigates to full TaperProgressScreen

## Files to modify/create

| File | Action |
|------|--------|
| `lib/data/database.dart` | Modify: new table, migration v13, CRUD methods, auto-add in insertTrackable |
| `lib/data/database.g.dart` | Regenerated by codegen |
| `lib/data/dashboard_widget_type.dart` | **New**: enum with parse/serialize/display |
| `lib/providers/database_providers.dart` | Modify: add `dashboardWidgetsProvider` |
| `lib/screens/dashboard_screen.dart` | Modify: switch to ConsumerStatefulWidget, use widgets provider, edit mode, add dialog |
| `lib/screens/dashboard/widgets/taper_progress_card.dart` | **New**: inline progress card |
| `test/dashboard_screen_test.dart` | Modify: update for widget-based dashboard |
| `test/dashboard_widgets_test.dart` | **New**: DB-level widget CRUD tests |
| `test/taper_progress_card_test.dart` | **New**: widget tests for inline progress card |

## Existing code to reuse

- `reorderTrackables()` pattern in `database.dart` → same transaction-based reorder for widgets
- `TrackableCard` widget → unchanged, just passed `trackableId` from widget table instead of trackable list
- `TaperProgressScreen._buildChart()` logic → adapted (not shared) for the inline card
- `DecayCurveChart` → used as-is inside TrackableCard
- `trackableCardDataProvider` → unchanged, still powers TrackableCard
- `activeTaperPlanProvider` → reused by TaperProgressCard
- `DashboardWidget` Drift data class → auto-generated by codegen

## What stays unchanged

- `isVisible` on trackables — still controls log form dropdown visibility
- `showCumulativeLine` on trackables — stays for backward compat, but dashboard reads from widget config JSON
- `TrackableCard` widget — zero changes, still watches `trackableCardDataProvider(trackableId)`
- `TaperProgressScreen` — unchanged full-screen view, card just navigates to it

## Verification

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test --timeout 10s
```

Manual testing:
1. Fresh install → dashboard shows Caffeine + Water cards (as before)
2. Tap edit icon → cards collapse to labels with drag handles + delete buttons
3. Drag to reorder → order persists after toggling edit mode off
4. Delete a widget → card disappears, trackable still exists in log form
5. Tap "Add Widget" → pick type → pick trackable → new card appears
6. Add a taper plan to a trackable → add a "Taper Progress" widget → inline chart renders
7. Tap the taper progress card → full TaperProgressScreen opens
8. Create a new trackable → decay_card auto-appears on dashboard
9. Delete a trackable → its dashboard widgets are cascade-deleted
