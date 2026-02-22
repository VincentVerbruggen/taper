# Plan: Database Export, Import & Auto-Backup

## Context

The app has no way to back up or restore data. If the user loses their phone or reinstalls, all dose history is gone. This feature adds:
1. **Manual export** — share the database file via the native share sheet
2. **Manual import** — pick a backup file, replace the database, refresh all providers
3. **Daily auto-backup** — on app launch, copy the DB to an internal `backups/` folder (7-day retention)

## Key Technical Details

- The DB file is `taper.sqlite` (not `.db`) in the app documents directory — `drift_flutter` names it `$name.sqlite`
- SQLite uses WAL mode, so we must run `PRAGMA wal_checkpoint(TRUNCATE)` before copying the file to flush writes
- After import, the Drift connection is stale. We use a "generation counter" provider that forces `databaseProvider` to rebuild, cascading to all downstream stream providers
- For export on mobile, `share_plus` opens the native share sheet (save to Files, email, Drive, etc.). `file_picker.saveFile()` only works on desktop
- For import, `file_picker.pickFiles()` works on all platforms

## Dependencies to Add

- `share_plus: ^10.0.0` — native share sheet for export
- `file_picker: ^8.0.0` — file picker for import

## Implementation Steps

### Step 1: Add dependencies to `pubspec.yaml`
Add `share_plus` and `file_picker`. Run `flutter pub get`.

### Step 2: Create `lib/services/backup_service.dart`
Pure file I/O service (singleton, same pattern as `NotificationService`).

Methods:
- `getDatabasePath()` — resolves `$documentsDir/taper.sqlite` (same logic as drift_flutter)
- `getBackupsDirectory()` — `$documentsDir/backups/`, creates if needed
- `prepareExportFile()` — copies DB to temp dir with timestamped name for sharing
- `importDatabase(pickedFilePath)` — validates SQLite magic bytes, copies picked file over `taper.sqlite`, deletes stale WAL/SHM files
- `isValidSqliteFile(path)` — checks first 16 bytes = `"SQLite format 3\0"`
- `performAutoBackup()` — copies DB to `backups/taper_backup_YYYY-MM-DD.sqlite`
- `isBackupDue(prefs)` — checks if last backup > 24h ago (or never done)
- `enforceRetention()` — keeps 7 newest backups, deletes rest (sorted by filename)
- `recordBackupTime(prefs)` / `getLastBackupTime(prefs)` — SharedPreferences read/write

SharedPreferences keys: `autoBackupEnabled` (bool), `lastBackupTime` (int millis).

### Step 3: Add `checkpointWal()` to `lib/data/database.dart`
One method on `AppDatabase`:
```dart
Future<void> checkpointWal() async {
  await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
}
```

### Step 4: Create `lib/providers/backup_providers.dart`
- `autoBackupEnabledProvider` — `NotifierProvider<..., bool>` backed by SharedPreferences (default: true)
- `lastBackupTimeProvider` — `Provider<DateTime?>` reads `lastBackupTime` from SharedPreferences
- `autoBackupStartupProvider` — `FutureProvider<void>` that runs auto-backup once on first watch (checks if enabled + due, then checkpoints WAL, copies file, enforces retention, records time)

### Step 5: Modify `lib/providers/database_providers.dart`
Add a `databaseGenerationProvider` (Notifier<int>, starts at 0). Update `databaseProvider` to `ref.watch(databaseGenerationProvider)` so incrementing the generation forces a fresh `AppDatabase()`. All downstream stream providers already `ref.watch(databaseProvider)`, so they cascade automatically.

### Step 6: Modify `lib/screens/home_screen.dart`
Convert from `StatefulWidget` to `ConsumerStatefulWidget`. Add `ref.watch(autoBackupStartupProvider)` in `build()` to trigger the one-time auto-backup on launch.

### Step 7: Modify `lib/screens/settings/settings_screen.dart`
Add a "Data" section with:
- **Auto-backup toggle** — SwitchListTile with last backup time as subtitle
- **Export Database** — ListTile, onTap: checkpoint WAL → prepare export file → `SharePlus.instance.share()`
- **Import Database** — ListTile, onTap: confirmation dialog → `FilePicker.platform.pickFiles()` → validate → close DB → import → increment generation counter → show success snackbar

### Step 8: Tests

**`test/services/backup_service_test.dart`** (new):
- `isValidSqliteFile()` with valid/invalid files
- `isBackupDue()` with various SharedPreferences states
- `enforceRetention()` with 0/5/7/10 backup files in a temp dir
- `listBackups()` returns sorted list

**`test/settings_screen_test.dart`** (extend existing):
- Verify export/import/auto-backup UI elements render
- Verify auto-backup toggle persists to SharedPreferences

## Files Changed

| File | Action |
|------|--------|
| `pubspec.yaml` | Modify — add share_plus, file_picker |
| `lib/services/backup_service.dart` | **Create** — file I/O service |
| `lib/providers/backup_providers.dart` | **Create** — backup settings providers |
| `lib/data/database.dart` | Modify — add `checkpointWal()` |
| `lib/providers/database_providers.dart` | Modify — add generation counter |
| `lib/screens/home_screen.dart` | Modify — ConsumerStatefulWidget + auto-backup trigger |
| `lib/screens/settings/settings_screen.dart` | Modify — export/import/auto-backup UI |
| `test/services/backup_service_test.dart` | **Create** — backup service unit tests |
| `test/settings_screen_test.dart` | Modify — new settings UI tests |

## Verification

1. Run `flutter test --timeout 10s` — all tests pass
2. Run `flutter analyze` — no warnings
3. Manual test on device/emulator:
   - Settings → Export → share sheet opens with `taper_backup_*.sqlite`
   - Settings → Import → pick the exported file → data reloads correctly
   - Kill app → relaunch → check `backups/` folder has a new backup file
   - Verify auto-backup doesn't run again within 24h
   - Toggle auto-backup off → kill/relaunch → verify no new backup created
