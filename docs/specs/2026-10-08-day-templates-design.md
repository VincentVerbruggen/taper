# Day Templates — Design

**Date:** 2026-10-08
**Status:** Implemented (revised during planning — see `plans/polished-foraging-locket.md`)

## Goal

In a trackable's day overview (`TrackableLogScreen`), let the user save the
current day's entries as a **named template** and later **apply** that template
to another day. Example: save Monday's caffeine plan as "Workday", then apply
"Workday" to Thursday with one tap.

This builds on the existing **Copy from another day…** action — a template is
essentially a saved, named source day that doesn't depend on the original day
still existing or being easy to find.

## Decisions

| Question | Decision |
|---|---|
| Scope | **Per trackable.** A template belongs to one trackable and is saved/applied from that trackable's day overview. |
| Target days | **Only the viewed day.** Applying to several days = navigate + apply again. |
| Existing entries on target day | **Add alongside.** Never deletes anything; Undo removes only the added rows. |
| Management | **Rename + delete** from the apply list. Edit contents by saving a day again under the same name (overwrite). |
| Planned flag | **Stored per entry.** Applied as stored, **except** on a future day where every entry becomes planned (same rule as Copy). |
| Time storage | **`"HH:MM"` text** (24h), like the existing `Targets.time` column. Day-boundary handling happens at apply time. |
| Skipped entries | **Excluded when saving** (amount 0). A day with only skips counts as empty. |
| Name matching | Case-insensitive, like every other name field (`duplicateNameError`). Overwrite keeps the existing name's casing. |
| Template list | **Dialog**, matching the app's other pickers (no bottom sheets in the app). |

## Data model (schema v19 → v20)

```
day_templates
  id            int PK autoincrement
  trackableId   int FK → trackables
  name          text            unique per trackable (enforced in app code)
  createdAt     datetime

day_template_entries
  id            int PK autoincrement
  templateId    int FK → day_templates
  time          text            "HH:MM", 24h, zero-padded ("08:30", "02:00")
  amount        real
  name          text nullable   preset name, e.g. "Espresso"
  isPlanned     bool            default false
```

- Migration: `if (from < 20)` creates both tables. No data backfill.
- **No database-level cascade exists in this schema** (no `onDelete`, no
  `PRAGMA foreign_keys`), despite comments suggesting otherwise. Therefore:
  - `deleteDayTemplate(id)` deletes its entries, then the template, in one
    transaction.
  - `deleteTrackable(id)` is extended to also delete that trackable's templates
    and their entries in the same transaction.
- Backups copy the whole SQLite file, so templates are included automatically.

## Time handling

Templates store clock time only. The day boundary (default 5 AM, configurable
in Settings) is applied when placing an entry onto a day:

- **Save:** each dose's `loggedAt` → `"HH:MM"` (seconds dropped).
- **Apply:** for a viewed day whose boundary is `D` at `boundaryHour`:
  - `HH < boundaryHour` → date is `D`'s calendar date **+ 1** (e.g. 02:00
    belongs to the night after that day).
  - otherwise → `D`'s calendar date.
  - Timestamp is built with `DateTime(y, m, d, HH, MM)` (not `add(Duration)`),
    so month overflow and DST are normalised by Dart.
- Exactly at the boundary (e.g. `05:00` with boundary 5) → same calendar date
  (start of the day).

If the user changes the boundary hour after saving a template, entries are
still placed inside the viewed day according to the *current* boundary.

## UI flow

Two new items in the existing overflow menu (⋮) of `TrackableLogScreen`, under
**Copy from another day…**:

### Save day as template…
- If the viewed day has no entries (skipped entries don't count) → SnackBar "No entries to save." and stop.
- Dialog with a name text field and Save / Cancel.
  - Save is **never disabled**. On press with empty/whitespace name →
    inline `errorText: 'Required'` (`submitted` flag pattern per CLAUDE.md).
  - Name is trimmed before saving.
  - If a template with that name (case-insensitive) already exists for this trackable →
    confirmation "Overwrite 'Workday'?" → on confirm, its entries are replaced
    (template id and `createdAt` are kept).
- On success → SnackBar "Saved template 'Workday' (4 entries)".

### Apply template…
- Dialog listing this trackable's templates, alphabetical, each row:
  name + subtitle "4 entries".
- Empty state: "No templates yet. Use 'Save day as template…' to create one."
- Tap a row → applies it to the viewed day and closes the dialog.
- Trailing ⋮ per row (tooltip "Template actions"):
  - **Rename** → dialog with name prefilled; same validation as save
    (Required, and duplicate name → inline "Name already exists", reusing
    `duplicateNameError`).
  - **Delete** → confirmation dialog → deletes template.

### Applying
- Entries are inserted **alongside** existing entries on the viewed day.
- `isPlanned` = `true` if the viewed day is in the future, else the stored
  entry value.
- SnackBar "Applied 'Workday' (4 entries)" (+ " as planned" for future days),
  6 seconds, close icon, **Undo** deletes only the rows just inserted.

## Code structure

`trackable_log_screen.dart` is already 864 lines, so new UI lives in its own
file and the screen only wires menu items.

- **`lib/data/database.dart`**
  - Tables `DayTemplates`, `DayTemplateEntries`; register in `@DriftDatabase`;
    `schemaVersion` → 20; migration.
  - `Stream<List<DayTemplateWithCount>> watchDayTemplates(int trackableId)`
    — templates + entry count, ordered by name (case-insensitive).
  - `Future<List<DayTemplate>> getDayTemplates(int trackableId)` — one-shot,
    for overwrite detection in the save dialog.
  - `Future<List<DayTemplateEntry>> getDayTemplateEntries(int templateId)`
  - `Future<int> saveDayTemplate({trackableId, name, doses, int? overwriteTemplateId})`
    — transaction: reuse `overwriteTemplateId` (replacing its entries) or
    insert a new template. The UI decides about overwriting, not the DB.
  - `Future<int> renameDayTemplate(int id, String name)`
  - `Future<void> deleteDayTemplate(int id)` — transaction, entries first.
  - Extend `deleteTrackable` to remove templates + entries (transaction).
  - Regenerate `database.g.dart` via build_runner.

- **`lib/utils/template_time.dart`** (pure, no Flutter imports)
  - `String toTemplateTime(DateTime t)` → `"HH:MM"`.
  - `DateTime placeOnDay(String hhmm, DateTime dayBoundary, int boundaryHour)`.

- **`lib/screens/dashboard/widgets/day_template_dialogs.dart`**
  - `showSaveTemplateDialog(...)` → `({String name, int? overwriteTemplateId})?`
    (overwrite already confirmed), or null.
  - `showRenameTemplateDialog(...)` → new name or null.
  - `showApplyTemplateDialog(...)` → picked `DayTemplate` or null; handles
    rename/delete internally.
- **`lib/providers/database_providers.dart`** — `dayTemplatesProvider` family.

- **`lib/screens/dashboard/trackable_log_screen.dart`**
  - Two new `PopupMenuItem`s.
  - Extract the existing "insert batch → SnackBar with Undo" tail of
    `_copyFromAnotherDay` into a shared `_insertBatchWithUndo(...)` used by both
    Copy and Apply template.

## Testing

All tests use fixed timestamps (e.g. `DateTime(2026, 2, 23, 12)`) and the
existing bounded-pump + dispose-before-close cleanup pattern. Run with
`flutter test --timeout 5s --fail-fast`.

**`test/utils/template_time_test.dart`**
- `toTemplateTime` zero-pads (`08:05`) and drops seconds.
- `08:30` with boundary 5 → same calendar date.
- `02:00` with boundary 5 → next calendar date.
- `05:00` with boundary 5 → same calendar date.
- Month overflow: `02:00` on a Jan 31 day → Feb 1.
- Placement across a DST transition date keeps the wall-clock time.

**`test/day_templates_test.dart`**
- DB: `saveDayTemplate` stores `HH:MM`/names/flags; counts + case-insensitive
  ordering; overwrite keeps the id; rename; `deleteDayTemplate` (with
  `PRAGMA foreign_keys = ON`); `deleteTrackable` removes only its templates.
- UI: save (incl. skipped entries left out); skip-only and empty day → "No
  entries to save."; empty name → "Required"; overwrite in a different case;
  apply on today keeps stored flags; apply on a future day → all planned;
  `02:00` lands on the next calendar date; apply adds alongside + Undo removes
  only applied rows; empty state; rename (incl. "Name already exists"); delete.
- Apply tests seed templates via the DB: a visible "Saved…" snackbar would
  queue the "Applied…" one behind it.

## Out of scope

- Templates spanning multiple trackables.
- Applying to a date range or by weekday.
- Replace / replace-planned-only modes.
- A dedicated template entry editor.
