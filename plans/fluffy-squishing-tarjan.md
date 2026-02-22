# Expressive Reorderable Trackables List

## Context

The current trackables list is a basic `ListTile` with a crowded trailing area (up/down arrows + pin button). Tapping the item navigates directly to edit. The user wants a more expressive design with:
- **Drag handle** for reordering (replacing up/down arrow buttons)
- **Pin button** prominently visible on each item
- **Three-dots menu** (`⋮`) with Edit, Toggle Visibility, and Delete actions

## Design

Each list item becomes:

```
┌──────────────────────────────────────────────────────┐
│  ≡  ● Caffeine                         📌    ⋮      │
│        mg · half-life: 5.0h                          │
└──────────────────────────────────────────────────────┘
```

- `≡` = drag handle (ReorderableDragStartListener)
- `●` = color dot (12px circle in trackable's color)
- `📌` = pin icon button (filled when pinned, outlined when not)
- `⋮` = three-dots `PopupMenuButton` with: Edit, Show/Hide, Delete

## Changes

### File: `lib/screens/trackables/trackables_screen.dart`

**`_TrackablesScreenState`:**
- Remove `onMoveUp`/`onMoveDown` callbacks from itemBuilder (no arrow buttons)
- Remove `isFirst`/`isLast` props
- Pass `index` to `_TrackableListItem` (needed for drag start listener)
- Add `_toggleVisibility(Trackable)` — calls `db.updateTrackable(id, isVisible: !current)`
- Add `_deleteTrackable(Trackable)` — shows confirmation dialog, calls `db.deleteTrackable(id)`, shows SnackBar
- Add `onToggleVisibility` and `onDelete` callbacks in itemBuilder

**`_TrackableListItem`:**
- Remove `isFirst`, `isLast`, `onMoveUp`, `onMoveDown` props
- Add `onToggleVisibility` and `onDelete` callbacks
- Add `index` prop (needed for `ReorderableDragStartListener`)
- **Leading:** Row of `ReorderableDragStartListener` (wrapping `Icon(Icons.drag_handle)`) + color dot
- **Trailing:** Row of pin `IconButton` + `PopupMenuButton` (`Icons.more_vert`)
- **PopupMenuButton items:**
  1. `Edit` (icon: `Icons.edit_outlined`) → calls `onEdit`
  2. `Show` / `Hide` (icon: `Icons.visibility` / `Icons.visibility_off`) → calls `onToggleVisibility`
  3. `Delete` (icon: `Icons.delete_outline`, destructive red text) → calls `onDelete`
- **Remove `onTap` from ListTile** — edit is now via the three-dots menu
- Keep subtitle, color dot, and hidden-item visual treatment (strikethrough + faded)

### File: `test/trackables_screen_test.dart`

Update tests:
- **Edit navigation tests** — open via three-dots menu → tap "Edit" instead of tapping the name
- **Pin button tests** — keep (pin icon still directly visible)
- **Remove** arrow icon expectations (no more up/down arrows)
- **Color dot tests** — keep
- **New test:** three-dots menu shows Edit, Show/Hide, Delete
- **New test:** toggle visibility from menu updates the trackable

## Verification

1. `flutter analyze` — 0 issues
2. `flutter test --timeout 10s` — all tests pass
3. Manual: drag handle reorders, pin toggles, three-dots menu works
