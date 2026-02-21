# Milestone 2: Dose Logging

## Context
Milestone 1 (Substance CRUD) is complete. Now we need the ability to log doses against substances — the core input mechanism for the app. A user picks a substance, enters an amount in mg, and the dose is saved with a timestamp.

## What We're Building

The **Log** tab (currently a placeholder) becomes a form with:
1. **Substance picker** — dropdown of all substances from the DB
2. **Amount input** — number field in mg (e.g., 90)
3. **Time picker** — defaults to "now", tappable to change
4. **Save button** — inserts the dose, resets the form, stays on the Log tab

## Database Changes

Add a `DoseLogs` table to `database.dart` and bump schema to v2 with migration.

**DoseLog columns:**
- `id` — auto-increment PK
- `substanceId` — integer FK referencing substances
- `amountMg` — real (double) for the dose amount
- `loggedAt` — dateTime for when the dose was consumed

**New DAO methods on AppDatabase:**
- `watchRecentDoseLogs()` — stream of recent logs (for later use on Dashboard)
- `insertDoseLog(substanceId, amountMg, loggedAt)`
- `deleteDoseLog(id)`

**Migration:** `onUpgrade` from v1→v2 creates the `dose_logs` table.

## Provider Changes

Add to `database_providers.dart`:
- `doseLogsProvider` — `StreamProvider` watching recent dose logs (will be used by Dashboard in M3)

## Files to Create/Modify

| File | Action | What |
|------|--------|------|
| `lib/data/database.dart` | Modify | Add DoseLogs table, DAO methods, bump schema + migration |
| `lib/providers/database_providers.dart` | Modify | Add doseLogsProvider |
| `lib/screens/log/log_dose_screen.dart` | Create | The log form (replaces placeholder) |
| `lib/screens/log_screen.dart` | Delete | Replaced by log_dose_screen.dart |
| `lib/screens/home_screen.dart` | Modify | Import new log screen |
| `test/helpers/test_database.dart` | Create | In-memory DB helper for widget tests |
| `test/log_dose_screen_test.dart` | Create | Widget test for the dose logging flow |

## Implementation Steps

### Step 1: DoseLogs table + migration in `database.dart`
- Add `DoseLogs extends Table` with id, substanceId, amountMg, loggedAt columns
- Add `DoseLogs` to `@DriftDatabase(tables: [Substances, DoseLogs])`
- Bump `schemaVersion` to 2
- Add `onUpgrade` migration that creates dose_logs table for v1→v2
- Add DAO methods: `insertDoseLog()`, `deleteDoseLog()`, `watchRecentDoseLogs()`
- Run `dart run build_runner build --delete-conflicting-outputs`

### Step 2: Provider in `database_providers.dart`
- Add `doseLogsProvider` StreamProvider

### Step 3: LogDoseScreen in `lib/screens/log/log_dose_screen.dart`
- `ConsumerStatefulWidget` (needs ref for providers)
- Substance dropdown — watches `substancesProvider`, renders `DropdownButtonFormField`
- Amount text field — number keyboard, "mg" suffix label
- Time display — shows current time, tappable to open time picker dialog
- Save button — validates (substance selected + amount > 0), inserts dose, resets form
- Form resets after save (substance stays selected for convenience, amount clears, time resets to now)

### Step 4: Wire up in `home_screen.dart`
- Replace `LogScreen` import with `LogDoseScreen`

### Step 5: Wire up + clean up
- Delete `lib/screens/log_screen.dart`
- Update import in `home_screen.dart`
- Run `flutter analyze`

### Step 6: Test helper — `test/helpers/test_database.dart`
- Create an `AppDatabase` factory that uses Drift's in-memory `NativeDatabase.memory()` connection
- This lets widget tests run without a real device/filesystem
- Like Laravel's `RefreshDatabase` trait — each test gets a fresh empty DB

### Step 7: Widget test — `test/log_dose_screen_test.dart`
- Override `databaseProvider` with the in-memory DB using `ProviderScope.overrides`
- Seed a substance into the test DB
- Pump the `LogDoseScreen` wrapped in `MaterialApp` + `ProviderScope`
- Test: select substance from dropdown, enter amount, tap Save
- Assert: dose is inserted in DB, form resets (amount field is empty again)

## Verification
```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run
```

Then on device:
- Go to Log tab → see form with substance dropdown, amount field, time
- Select "Caffeine", enter "90", save → form resets, dose is in the DB
- Add a second substance, log a dose for that one too
- Delete a substance → its doses should cascade-delete (we'll verify this)
