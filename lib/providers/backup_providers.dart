import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/services/backup_service.dart';

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

/// One-shot auto-backup that runs on app launch.
///
/// FutureProvider = runs once when first watched, caches the result.
/// Like a Laravel boot() method that checks if a scheduled task is due.
///
/// Checks: is auto-backup enabled? Is it due (>24h since last)?
/// If yes: checkpoint WAL → copy DB to backups/ → enforce retention → record time.
/// Errors are caught silently — backup failures shouldn't crash the app.
final autoBackupStartupProvider = FutureProvider<void>((ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final enabled = prefs.getBool(BackupService.autoBackupEnabledKey) ?? true;
  if (!enabled) return;

  final backup = BackupService.instance;
  if (!backup.isBackupDue(prefs)) return;

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
    final externalFolder =
        prefs.getString(BackupService.externalBackupFolderKey);
    if (externalFolder != null && externalFolder.isNotEmpty) {
      try {
        await backup.mirrorBackupToExternal(backupFile, externalFolder);
      } catch (_) {
        // Swallow — internal backup already succeeded.
      }
    }
  } catch (_) {
    // Non-fatal — auto-backup is best-effort.
    // Like a Laravel job that catches exceptions and moves on.
  }
});
