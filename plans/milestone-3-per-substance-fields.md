# Milestone 3: Per-Substance Fields (Units, Half-Life, Color)

## Context

The substance table currently only stores `name`, `isMain`, and `isVisible`. To enable the decay curve chart (Milestone 4), substances need a `halfLifeHours` field. While we're adding schema fields, we also add `unit` (so amounts aren't hardcoded to "mg") and `color` (auto-assigned, for chart lines later). The `amountMg` column in dose_logs gets renamed to `amount` since the unit now comes from the substance.

## Key Decisions

- **halfLifeHours**: Nullable. `null` = no decay tracking (e.g., Water). This keeps the decay calculator clean — just skip substances with null half-life.
- **unit**: Free text input, defaults to "mg". Stored on the substance, displayed everywhere amounts appear.
- **color**: Auto-assigned from a 10-color palette based on creation order. No user-facing picker yet — just a visual indicator in the substance list.
- **Column rename**: `ALTER TABLE dose_logs RENAME COLUMN amount_mg TO amount` (SQLite 3.25+, bundled by sqlite3_flutter_libs).

## Implementation Steps

### Step 1: Schema changes + code gen

**`lib/data/database.dart`**

1. Add `substanceColorPalette` constant (10 distinct ARGB ints) at top of file
2. Add to `Substances` table:
   - `halfLifeHours` — `real().nullable()()`
   - `unit` — `text().withDefault(const Constant('mg'))()`
   - `color` — `integer()()` (non-nullable, no default — always explicitly set)
3. Rename `amountMg` to `amount` in `DoseLogs` table
4. Run `dart run build_runner build --delete-conflicting-outputs`

### Step 2: Migration v3 → v4

**`lib/data/database.dart`** — bump `schemaVersion` to 4, add `if (from < 4)` block:

1. `m.addColumn(substances, substances.halfLifeHours)` — nullable, existing rows get NULL
2. `m.addColumn(substances, substances.unit)` — has default, existing rows get "mg"
3. `customStatement("ALTER TABLE substances ADD COLUMN color INTEGER NOT NULL DEFAULT 0")` — can't use `m.addColumn` for non-nullable without default on existing tables
4. Query all existing substances ordered by id, assign colors from palette by index
5. `customStatement("ALTER TABLE dose_logs RENAME COLUMN amount_mg TO amount")`

### Step 3: Update seeder

**`lib/data/database.dart`** — `onCreate` seeder:

- Caffeine: `halfLifeHours: 5.0, unit: "mg", color: palette[0]`
- Water: `halfLifeHours: null, unit: "ml", color: palette[1]`
- Alcohol: `halfLifeHours: 4.0, unit: "ml", isVisible: false, color: palette[2]`

No changes to the `from < 3` upgrade seeder — the `from < 4` block assigns colors to those substances too.

### Step 4: Update database methods

**`lib/data/database.dart`**

- `insertSubstance(name, {unit, halfLifeHours})` — auto-assigns color from palette using `count % palette.length`
- `updateSubstance(id, {name, unit, halfLifeHours})` — named params, uses `Value<double?>` for halfLifeHours to distinguish "set to null" vs "don't change"
- `insertDoseLog` / `updateDoseLog` — rename `amountMg` param to `amount`, update companion field names

### Step 5: Fix screens (compile errors + dynamic unit)

**`lib/screens/log/log_dose_screen.dart`**
- Amount field: `suffixText: _selectedSubstance?.unit ?? 'mg'` (remove `const` from InputDecoration)
- Recent logs: `entry.doseLog.amount` + `entry.substance.unit` instead of hardcoded "mg"

**`lib/screens/log/edit_dose_screen.dart`**
- Same: dynamic suffix, `doseLog.amount` instead of `doseLog.amountMg`

**`lib/screens/substances/substances_screen.dart`**
- `updateSubstance` call: switch to named params

### Step 6: Expand substance form

**`lib/screens/substances/substances_screen.dart`**

Expand `_SubstanceFormCard`:
- Add `unit` TextField (free text, default "mg")
- Add `halfLifeHours` TextField (number input, optional, hint: "e.g. 5.0")
- `onSave` callback now passes `(name, unit, halfLifeHours)`
- Edit mode pre-fills from existing substance

Update `_SubstanceListItem`:
- Add subtitle showing unit + half-life (e.g., `mg · half-life: 5.0h`)
- Add small color dot indicator

### Step 7: Fix tests + add new tests

**`test/log_dose_screen_test.dart`**
- Fix `doseLog.amountMg` → `doseLog.amount` in assertions (~3 occurrences)
- Add test: unit suffix changes when selecting different substance
- Add test: recent log entry shows substance's unit

**`test/substances_screen_test.dart`** (new file)
- Add substance with unit + half-life → verify DB values
- Edit substance unit + half-life → verify update
- Half-life is optional → saves as null
- Color auto-assigned from palette
- Color cycles through palette for multiple substances

### Step 8: Run full test suite + update docs

- `flutter test --timeout 10s`
- Update `CLAUDE.md` data models section (new fields, schema v4)

## Files to modify

| File | What changes |
|------|-------------|
| `lib/data/database.dart` | Palette, table defs, migration, seeder, all query methods |
| `lib/data/database.g.dart` | Regenerated (never edit) |
| `lib/screens/substances/substances_screen.dart` | Form fields, list display, method signatures |
| `lib/screens/log/log_dose_screen.dart` | Dynamic unit suffix, amountMg→amount |
| `lib/screens/log/edit_dose_screen.dart` | Dynamic unit suffix, amountMg→amount |
| `test/log_dose_screen_test.dart` | Fix amountMg refs, add unit tests |
| `test/substances_screen_test.dart` | New file: substance form tests |
| `CLAUDE.md` | Update data models + schema version |

## Verification

1. `dart run build_runner build --delete-conflicting-outputs` — no errors
2. `flutter analyze` — no warnings
3. `flutter test --timeout 10s` — all tests pass
4. Manual: run app, check substance form has unit + half-life fields
5. Manual: log a dose for Water → suffix shows "ml" not "mg"
6. Manual: recent logs show correct unit per substance
