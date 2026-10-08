# Day Templates — Implementation Plan

Spec: `docs/specs/2026-10-08-day-templates-design.md`

## Context

In the per-trackable day overview (`TrackableLogScreen`) the user wants to save
the current day's entries as a **named template** and later **apply** it to the
day being viewed. It builds on the existing "Copy from another day…" action,
which already does the hard part: read a day, shift times, mark future entries
planned, insert with an Undo snackbar.

## Decisions

| Topic | Decision |
|---|---|
| Scope | Per trackable, saved/applied from its day overview |
| Target | Only the viewed day; entries added alongside existing ones |
| Management | Rename + delete from the apply list; overwrite by saving the same name |
| Time storage | `"HH:MM"` text; boundary handled at apply time |
| Skipped entries (amount 0) | **Excluded when saving** — a day with only skips = "No entries to save." |
| Planned flag on apply | `true` on a future day, else stored flag (incl. today) — same as Copy |
| Name matching | Case-insensitive (matches `duplicateNameError`); overwrite keeps the existing name's casing |
| Duplicate-name error text | Reuse `duplicateNameError` → "Name already exists" |
| Template list UI | **Dialog** (not bottom sheet) — matches every other picker in the app |
| Widget tests | **New** `test/day_templates_test.dart` |

## Facts from the codebase that shape the plan

- `insertDoseLog` (`database.dart:1266`) fires `ReminderScheduler.onDoseLogged`
  (fire-and-forget) for non-planned doses → applying goes through it one row at
  a time, exactly like Copy. **Never wrap these inserts in `transaction()`** —
  the scheduler's background reads would hit a closed transaction.
- `duplicateNameError` (`lib/utils/validation.dart:50`) → reused for rename.
- Dialog pattern = `showDialog` + `StatefulBuilder` + local `submitted` flag
  (`presets_screen.dart:117-220`); controllers are not disposed (disposing right
  after `await showDialog` crashes during the close animation).
- One-shot list before opening a dialog = `db.getPresets(...)` pattern
  (`trackable_log_screen.dart:114`).
- List provider pattern = `presetsProvider` (`database_providers.dart:190`).
- No FK enforcement (`test/reminders_database_test.dart:247`) → explicit deletes.
- Drift 2.31 generates `DayTemplate` / `DayTemplateEntry` data classes.
- Flutter queues snackbars: a visible "Saved…" snackbar delays the next one →
  widget tests seed templates via the DB, not via the save UI.

## Implementation steps

Complexity: S = small, M = medium. Steps 1–3 are independent of each other.

### Step 1 (S) — `lib/utils/template_time.dart` + `test/utils/template_time_test.dart`
- `String toTemplateTime(DateTime t)` → zero-padded `"HH:MM"`, seconds dropped.
- `DateTime placeOnDay(String hhmm, DateTime dayBoundary, int boundaryHour)`:
  `hour < boundaryHour` → calendar date + 1, else same date; built with
  `DateTime(y, m, d + offset, h, min)` (DST/month-overflow safe). `boundaryHour`
  is explicit because a DST-forward day can shift `dayBoundary.hour`.
- `int.parse` (data is always written by `toTemplateTime`).
- Tests: `08:05` padding/seconds dropped; `08:30` same date; `02:00` next date;
  `05:00` same; `04:59` next; Jan 31 `02:00` → Feb 1; boundary 3 (`04:00` same,
  `02:00` next); 2026-03-29 `08:30` keeps 8:30 (timezone-independent assertion).

### Step 2 (S) — Extract `_insertBatchWithUndo` in `trackable_log_screen.dart`
- `typedef _NewDose = ({double amount, DateTime loggedAt, String? name, bool isPlanned});`
  (Dart 3 record — like a typed PHP array shape).
- `_insertBatchWithUndo({required AppDatabase db, required ScaffoldMessengerState messenger, required List<_NewDose> doses, required String message})`
  — caller captures `db` and `messenger` **before** its first `await` (Riverpod 3
  throws on `ref` after unmount); helper keeps the `if (!mounted) return;` after
  the insert loop, `persist: false`, 6s duration, close icon, Undo deleting only
  the inserted ids.
- `_copyFromAnotherDay` uses it; behaviour and text unchanged.
- Verify: existing copy tests in `test/trackable_log_screen_test.dart` pass.

### Step 3 (M) — Data layer in `lib/data/database.dart`
- Tables after `Targets` (with Laravel-style schema comments like the others):
  - `DayTemplates`: `id`, `trackableId` → `references(Trackables, #id)`, `name`,
    `createdAt` → `dateTime().clientDefault(DateTime.now)`.
  - `DayTemplateEntries`: `id`, `templateId` → `references(DayTemplates, #id)`,
    `time` text, `amount` real, `name` nullable, `isPlanned` default false.
- Register in `@DriftDatabase`; `schemaVersion` → 20;
  `if (from < 20) { createTable(dayTemplates); createTable(dayTemplateEntries); }`.
- `class DayTemplateWithCount { final DayTemplate template; final int entryCount; }`
  next to `DoseLogWithTrackable`.
- `// --- Day template queries ---`:
  - `watchDayTemplates(trackableId)` — `select(dayTemplates).join([leftOuterJoin(dayTemplateEntries, …, useColumns: false)])`,
    local `entryCount = dayTemplateEntries.id.count()` in `addColumns`,
    `groupBy([dayTemplates.id])`, order by `name.collate(Collate.noCase)`,
    read with `row.read(entryCount) ?? 0`.
  - `getDayTemplates(trackableId)` — one-shot, same ordering.
  - `getDayTemplateEntries(templateId)` — ordered by `time`.
  - `saveDayTemplate({trackableId, name, List<DoseLog> doses, int? overwriteTemplateId})`
    — transaction: overwrite → delete its entries and reuse the id, else insert
    the template; insert one entry per dose via `toTemplateTime`. Returns id.
  - `renameDayTemplate(id, name)`.
  - `deleteDayTemplate(id)` — transaction, entries first.
  - `deleteTrackable(id)` → transaction: delete entries where `templateId.isInQuery(selectOnly(dayTemplates)..addColumns([dayTemplates.id])..where(trackableId == id))`,
    then templates, then the trackable. Still returns `Future<int>`.
- `dart run build_runner build --delete-conflicting-outputs`.
- DB tests (group in `test/day_templates_test.dart`), using hand-built `DoseLog(...)`
  objects and `.first` on streams:
  - counts + case-insensitive name ordering;
  - overwrite replaces entries and keeps the id;
  - `deleteDayTemplate` removes entries (also with `PRAGMA foreign_keys = ON`);
  - `deleteTrackable` removes its templates + entries, other trackables' stay.
- Verify `test/reminders_database_test.dart` still passes.

### Step 4 (S) — `lib/providers/database_providers.dart`
- `dayTemplatesProvider = StreamProvider.family<List<DayTemplateWithCount>, int>`
  → `db.watchDayTemplates(trackableId)`.

### Step 5 (M) — `lib/screens/dashboard/widgets/day_template_dialogs.dart` (new)
- `showSaveTemplateDialog({context, required List<DayTemplate> existing})`
  → `({String name, int? overwriteTemplateId})?`
  - Name field (autofocus, hint "e.g. Workday"); Save always enabled;
    empty → `submitted` → `'Required'`.
  - Case-insensitive match → overwrite confirm opened with the outer
    `dialogContext` ("Overwrite 'Workday'?" / "Its entries will be replaced with
    this day's entries."); check `dialogContext.mounted` after the await;
    confirm → pop `(name: match.name, overwriteTemplateId: match.id)`;
    cancel → stay in the name dialog.
- `showRenameTemplateDialog({context, required DayTemplate template, required List<String> otherNames})`
  → `String?`; `'Required'` after submit, `duplicateNameError` live.
- `showApplyTemplateDialog({context, required int trackableId})` → `DayTemplate?`
  - `Consumer` watching `dayTemplatesProvider`; loading = fixed-height
    placeholder (no spinner, so a query error can't stall `pumpAndSettle`).
  - `SizedBox(width: double.maxFinite)` + `ListView(shrinkWrap: true)`; rows with
    `ValueKey(template.id)`, title = name, subtitle "1 entry"/"N entries",
    tap → pop(template).
  - Trailing `PopupMenuButton<_TemplateAction>` (enum, tooltip
    "Template actions"): Rename → rename dialog → `renameDayTemplate`;
    Delete → confirm "Delete 'Workday'?" → `deleteDayTemplate`. Nested dialogs use
    the apply dialog's `dialogContext` + `mounted` check.
  - Empty state: "No templates yet. Use 'Save day as template…' to create one."
  - Cancel action.

### Step 6 (M) — Wire into `trackable_log_screen.dart`
- Menu items under Copy: `'saveTemplate'` "Save day as template…"
  (`Icons.bookmark_add_outlined`), `'applyTemplate'` "Apply template…"
  (`Icons.bookmarks_outlined`); `onSelected` becomes a `switch`.
- `_saveDayAsTemplate({selectedBoundary, endBoundary})`: capture db/messenger →
  `getDosesBetween` → drop `amount == 0` → empty ⇒ "No entries to save." →
  `getDayTemplates` → dialog → `saveDayTemplate` →
  "Saved template 'Workday' (4 entries)".
- `_applyTemplate({boundaryHour, selectedBoundary, todayBoundary})`: capture
  db/messenger → dialog → `getDayTemplateEntries` → map with `placeOnDay` and
  `isPlanned: targetIsFuture || e.isPlanned` → `_insertBatchWithUndo` with
  "Applied 'Workday' (4 entries)" + " as planned" on future days.

### Step 7 (M) — Widget tests in `test/day_templates_test.dart`
Same harness as `trackable_log_screen_test.dart` (fixed now 2026-02-23 12:00,
cleanUp disposes the tree before `db.close()`). Templates for apply tests are
seeded with `db.saveDayTemplate`. Finders: exact snackbar strings, dialog-scoped
buttons via `find.descendant(of: find.byType(AlertDialog).last, …)`, row menu
via its tooltip.
- Save → entries stored (`'09:00'`, `'14:30'`, names, flags) + snackbar.
- Skipped entries not saved; skip-only day and empty day → "No entries to save."
- Empty name → "Required", dialog stays.
- Existing name in different case → overwrite confirm → replaced, 1 template.
- Apply on today → times/amounts/names match, stored flags kept.
- Apply on future day → all planned, "as planned".
- `'02:00'` entry applied to Feb 23 → `DateTime(2026,2,24,2)`, listed on Feb 23.
- Alongside existing entries; Undo removes only applied rows.
- Empty state; rename (incl. "Name already exists"); delete with confirm.

### Step 8 (S) — Finish
- Bring the spec in line with the plan's revisions: dialog instead of bottom
  sheet, "Name already exists", the method names, `overwriteTemplateId`, and
  skipped entries being excluded.
- `flutter analyze`; `flutter test --timeout 5s --fail-fast` (full suite).
- Manual run on a device with existing data (v19 → v20 migration): save, apply
  to today/future, undo, rename, delete.

## What NOT to change
- Copy-from-day behaviour or texts (only the extraction refactor).
- `trackable_card.dart` target placement (its DST-unsafe `add(Duration)`).
- FK pragma / orphan cleanup for doses, presets, reminders, etc. on trackable delete.
- Backup service (whole-file copy already includes the new tables).
- `CLAUDE.md`, and no git operations (the developer handles commits).
