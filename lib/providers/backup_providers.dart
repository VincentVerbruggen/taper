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
    await backup.performAutoBackup();
    backup.recordBackupTime(prefs);
  } catch (_) {
    // Non-fatal — auto-backup is best-effort.
    // Like a Laravel job that catches exceptions and moves on.
  }
});
