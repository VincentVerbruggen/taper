import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/services/backup_service.dart';
import 'package:taper/services/storage_permission.dart';

/// Whether daily auto-backup is enabled. Defaults to true.
///
/// Persisted in SharedPreferences so the setting survives app restarts.
/// Like a Laravel config value stored in the database:
///   Setting::firstOrCreate(['key' => 'auto_backup'], ['value' => true])
final autoBackupEnabledProvider =
    NotifierProvider<AutoBackupEnabledNotifier, bool>(
  AutoBackupEnabledNotifier.new,
);

class AutoBackupEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(BackupService.autoBackupEnabledKey) ?? true;
  }

  void setEnabled(bool value) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setBool(BackupService.autoBackupEnabledKey, value);
    state = value;
  }
}

/// Optional external folder where each auto-backup is mirrored.
///
/// Null = no external mirroring (internal backups only).
/// Persisted in SharedPreferences as a plain path string.
final externalBackupFolderProvider =
    NotifierProvider<ExternalBackupFolderNotifier, String?>(
  ExternalBackupFolderNotifier.new,
);

class ExternalBackupFolderNotifier extends Notifier<String?> {
  @override
  String? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final value = prefs.getString(BackupService.externalBackupFolderKey);
    // Treat empty string as null — defensive against stale prefs.
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> setFolder(String? path) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (path == null || path.isEmpty) {
      await prefs.remove(BackupService.externalBackupFolderKey);
      state = null;
    } else {
      await prefs.setString(BackupService.externalBackupFolderKey, path);
      state = path;
    }
  }
}

/// The last auto-backup time, or null if never backed up.
///
/// Read-only provider — the BackupService writes this via SharedPreferences,
/// and we just read it here. Like a computed property that reads from cache.
final lastBackupTimeProvider = Provider<DateTime?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BackupService.instance.getLastBackupTime(prefs);
});

/// The last time an auto-backup was successfully mirrored to the external
/// folder, or null if never. Read-only, like [lastBackupTimeProvider].
final lastExternalBackupTimeProvider = Provider<DateTime?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BackupService.instance.getLastExternalBackupTime(prefs);
});

/// The last backup error message, or null if the last attempt fully succeeded.
/// Lets Settings show *why* a backup didn't land instead of it failing silently.
final lastBackupErrorProvider = Provider<String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BackupService.instance.getLastBackupError(prefs);
});

/// Whether we currently hold the "All files access" grant needed to mirror
/// backups to a shared-storage folder.
///
/// FutureProvider because the check is async (a plugin call). Settings watches
/// this to show a "grant access" prompt; after the user grants it, call
/// `ref.invalidate(storagePermissionGrantedProvider)` to re-check.
final storagePermissionGrantedProvider = FutureProvider<bool>((ref) {
  return StoragePermission.isGranted();
});

/// Shared backup execution: checkpoint WAL, copy the DB to today's dated
/// backup file (overwriting it if one already exists for today), record the
/// backup time, and best-effort mirror to the external folder if configured.
///
/// Pulled out into its own function because both the app-launch check and
/// the on-change rolling backup below need to do exactly this.
/// Errors are caught silently — backup failures shouldn't crash the app.
/// Like a Laravel job that catches exceptions and moves on.
Future<void> _performBackup(Ref ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final backup = BackupService.instance;

  try {
    // Flush WAL first so the copy gets all recent writes.
    final db = ref.read(databaseProvider);
    await db.checkpointWal();

    // Copy DB to backups/ with today's date, trim old backups.
    final backupFile = await backup.performAutoBackup();
    backup.recordBackupTime(prefs);

    // Mirror to the user's external folder if configured. Best-effort —
    // a permission error or missing folder shouldn't undo the internal
    // backup we just took. Like a Laravel job that logs and moves on.
    //
    // We now RECORD the outcome instead of silently swallowing it: the mirror
    // is exactly the part that was failing invisibly (no "All files access"
    // grant), so its success/failure is written to prefs for Settings to show.
    final externalFolder =
        prefs.getString(BackupService.externalBackupFolderKey);
    if (externalFolder != null && externalFolder.isNotEmpty) {
      // Pre-check the "All files access" grant. Without it, dart:io writes to
      // shared storage fail with a cryptic OS error (EPERM / "operation not
      // permitted"). This commonly happens after a reinstall: Android restores
      // the saved folder preference from its auto-backup, but a runtime grant
      // can't be restored — so we'd otherwise mirror into a folder we can't
      // write to. Record an actionable message instead of the raw errno.
      if (!await StoragePermission.isGranted()) {
        backup.recordBackupError(
          prefs,
          "External backup needs 'All files access'. Enable it under "
          'Settings → Apps → Special app access → All files access, '
          'or re-pick the folder to be prompted.',
        );
      } else {
        try {
          await backup.mirrorBackupToExternal(backupFile, externalFolder);
          backup.recordExternalBackupTime(prefs);
          backup.recordBackupError(prefs, null); // Clear any previous failure.
        } catch (e) {
          // Don't rethrow — the internal backup already succeeded. Just record
          // why the folder stayed empty so the user isn't left guessing.
          backup.recordBackupError(prefs, 'External backup failed: $e');
        }
      }
    } else {
      // No external folder configured — nothing to mirror; clear stale errors.
      backup.recordBackupError(prefs, null);
    }
  } catch (e) {
    // Even the internal backup failed — record it, but never crash the app.
    backup.recordBackupError(prefs, 'Backup failed: $e');
  }
}

/// One-shot auto-backup that runs on app launch.
///
/// FutureProvider = runs once when first watched, caches the result.
/// Like a Laravel boot() method that checks if a scheduled task is due.
///
/// Checks: is auto-backup enabled? Is it due (>24h since last)?
/// This is a safety net for the case where the app hasn't been opened (and
/// so [autoBackupOnChangeProvider] hasn't had a chance to run) in a while.
final autoBackupStartupProvider = FutureProvider<void>((ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final enabled = prefs.getBool(BackupService.autoBackupEnabledKey) ?? true;
  if (!enabled) return;
  if (!BackupService.instance.isBackupDue(prefs)) return;

  await _performBackup(ref);
});

/// Rolling daily backup: fires a (debounced) backup whenever any table in
/// the database changes, so today's backup file always reflects the latest
/// data instead of only whatever existed the last time the app was launched.
///
/// Hooks into Drift's built-in tableUpdates() stream — the same stream that
/// powers watch() queries — so every insert/update/delete anywhere in the
/// app (dose logs, trackables, reminders, ...) is covered automatically,
/// without having to call this from every individual save button.
/// Like a model observer that fires on every Eloquent save/delete, rather
/// than a scheduled job that only runs once a day.
///
/// Writes are debounced by a few seconds so a burst of changes (e.g.
/// deleting several dose logs back to back) results in one backup copy
/// instead of one per change.
final autoBackupOnChangeProvider = Provider<void>((ref) {
  final enabled = ref.watch(autoBackupEnabledProvider);
  if (!enabled) return;

  final db = ref.watch(databaseProvider);

  Timer? debounceTimer;
  final subscription = db.tableUpdates().listen((_) {
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(seconds: 3), () {
      // Fire-and-forget: _performBackup swallows its own errors.
      unawaited(_performBackup(ref));
    });
  });

  // Cancel both the subscription and any pending debounce when this
  // provider is torn down (e.g. auto-backup gets toggled off), so we never
  // fire a backup — or touch a disposed ref — after that point.
  ref.onDispose(() {
    debounceTimer?.cancel();
    subscription.cancel();
  });

  // Nothing meaningfully "watches" this provider's return value —
  // home_screen.dart just reads it once to start the listener. keepAlive()
  // stops Riverpod from tearing the subscription down right after that.
  ref.keepAlive();
});
