import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles all database backup file I/O operations.
///
/// Pure file operations — no UI, no Riverpod, no Drift.
/// Think of it like a Laravel Storage facade: BackupService::export(), etc.
///
/// Singleton pattern (same as NotificationService) — one instance globally.
class BackupService {
  // --- Singleton ---
  static final instance = BackupService._();
  BackupService._();

  /// SharedPreferences key for the auto-backup toggle.
  static const autoBackupEnabledKey = 'autoBackupEnabled';

  /// SharedPreferences key for the last backup timestamp (epoch millis).
  static const lastBackupTimeKey = 'lastBackupTime';

  /// Maximum number of auto-backup files to keep.
  /// Oldest beyond this limit are deleted automatically.
  static const maxBackups = 7;

  /// The first 16 bytes of every valid SQLite file.
  /// This is the "magic string" that identifies a file as SQLite.
  /// Like checking a file's MIME type by reading its magic bytes.
  static final _sqliteMagic = 'SQLite format 3\x00'.codeUnits;

  /// Get the path to the active database file (taper.sqlite).
  ///
  /// drift_flutter resolves this as: $documentsDir/taper.sqlite
  /// We replicate that resolution here so we can copy the file.
  /// Like resolving storage_path('app.sqlite') in Laravel.
  Future<String> getDatabasePath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return p.join(docsDir.path, 'taper.sqlite');
  }

  /// Get (or create) the backups directory: $documentsDir/backups/
  ///
  /// Auto-backups are stored here with dated filenames.
  /// Like Laravel's storage/app/backups/ directory.
  Future<Directory> getBackupsDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final backupsDir = Directory(p.join(docsDir.path, 'backups'));
    // Create the directory if it doesn't exist (recursive = create parents too).
    // Like Storage::makeDirectory('backups') in Laravel.
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }
    return backupsDir;
  }

  /// Prepare a copy of the database for sharing/exporting.
  ///
  /// Copies the DB to a temp directory with a timestamped name so the user
  /// gets a meaningful filename in the share sheet (not just "taper.sqlite").
  ///
  /// IMPORTANT: Caller must run db.checkpointWal() BEFORE calling this
  /// to flush WAL writes into the main .sqlite file.
  ///
  /// Returns the temporary File ready to pass to share_plus.
  Future<File> prepareExportFile() async {
    final dbPath = await getDatabasePath();
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      throw FileSystemException('Database file not found', dbPath);
    }

    // Build a timestamped filename: taper_backup_2026-02-22_143000.sqlite
    // The timestamp makes each export uniquely identifiable.
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${_pad(now.month)}-${_pad(now.day)}_'
        '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    final exportName = 'taper_backup_$timestamp.sqlite';

    // Copy to the system temp directory — a scratch area that the OS cleans up.
    // Like Laravel's sys_get_temp_dir() for temporary file operations.
    final tempDir = await getTemporaryDirectory();
    final exportPath = p.join(tempDir.path, exportName);

    return dbFile.copy(exportPath);
  }

  /// Check if a file is a valid SQLite database by reading its magic bytes.
  ///
  /// Every SQLite file starts with "SQLite format 3\0" (16 bytes).
  /// Like checking a file upload's MIME type before processing it.
  Future<bool> isValidSqliteFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;

      // Read just the first 16 bytes — no need to load the whole file.
      final raf = await file.open(mode: FileMode.read);
      try {
        final Uint8List header = await raf.read(16);
        if (header.length < 16) return false;

        // Compare byte-by-byte against the SQLite magic string.
        for (var i = 0; i < _sqliteMagic.length; i++) {
          if (header[i] != _sqliteMagic[i]) return false;
        }
        return true;
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  /// Import a database file: replace the active taper.sqlite with the picked file.
  ///
  /// IMPORTANT: The caller must close the active Drift database BEFORE calling this.
  /// After this returns, the caller should increment the databaseGenerationProvider
  /// to force a fresh DB connection.
  ///
  /// Steps:
  ///   1. Validate SQLite magic bytes
  ///   2. Copy the picked file over taper.sqlite
  ///   3. Delete stale WAL and SHM files (they belong to the old DB)
  ///
  /// Returns true on success, false if validation fails.
  /// Throws on file I/O errors.
  Future<bool> importDatabase(String pickedFilePath) async {
    // Validate the file before touching anything.
    if (!await isValidSqliteFile(pickedFilePath)) return false;

    final dbPath = await getDatabasePath();
    final pickedFile = File(pickedFilePath);

    // Overwrite the active database with the imported file.
    // Like `cp imported.sqlite taper.sqlite` — a full file replacement.
    await pickedFile.copy(dbPath);

    // Delete leftover WAL and SHM files from the old database.
    // These are write-ahead log files tied to the previous DB state.
    // If we don't delete them, SQLite might try to replay old WAL entries
    // against the new file, corrupting it.
    // Like clearing Redis cache after swapping the database.
    final walFile = File('$dbPath-wal');
    final shmFile = File('$dbPath-shm');
    if (await walFile.exists()) await walFile.delete();
    if (await shmFile.exists()) await shmFile.delete();

    return true;
  }

  /// Perform an auto-backup: copy the DB to backups/taper_backup_YYYY-MM-DD.sqlite.
  ///
  /// IMPORTANT: Caller must run db.checkpointWal() BEFORE calling this.
  ///
  /// After copying, enforces the retention limit (deletes oldest beyond 7).
  /// Returns the backup File on success.
  Future<File> performAutoBackup() async {
    final dbPath = await getDatabasePath();
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      throw FileSystemException('Database file not found', dbPath);
    }

    final backupsDir = await getBackupsDirectory();
    final now = DateTime.now();
    // Use just the date (no time) — one backup per day max.
    final backupName =
        'taper_backup_${now.year}-${_pad(now.month)}-${_pad(now.day)}.sqlite';
    final backupPath = p.join(backupsDir.path, backupName);

    final backupFile = await dbFile.copy(backupPath);

    // Clean up old backups beyond the retention limit.
    await enforceRetention();

    return backupFile;
  }

  /// Check if an auto-backup is due (never done, or last backup > 24h ago).
  ///
  /// Reads the lastBackupTime from SharedPreferences.
  /// Like checking a Laravel scheduled task's last run time.
  bool isBackupDue(SharedPreferences prefs) {
    final lastMs = prefs.getInt(lastBackupTimeKey);
    if (lastMs == null) return true; // Never backed up.

    final lastTime = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final elapsed = DateTime.now().difference(lastTime);
    return elapsed.inHours >= 24;
  }

  /// Record the current time as the last backup time.
  void recordBackupTime(SharedPreferences prefs) {
    prefs.setInt(lastBackupTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Get the last backup time, or null if never backed up.
  DateTime? getLastBackupTime(SharedPreferences prefs) {
    final ms = prefs.getInt(lastBackupTimeKey);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  /// List all backup files in the backups directory, sorted newest first.
  ///
  /// Sorts by filename (which includes the date), so alphabetical = chronological.
  /// Like `ls -t storage/app/backups/` in a Laravel artisan command.
  Future<List<File>> listBackups() async {
    final backupsDir = await getBackupsDirectory();
    if (!await backupsDir.exists()) return [];

    final files = await backupsDir
        .list()
        .where((entity) =>
            entity is File && p.basename(entity.path).startsWith('taper_backup_'))
        .cast<File>()
        .toList();

    // Sort by filename descending (newest date first).
    files.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    return files;
  }

  /// Delete backups beyond the retention limit (keeps newest 7).
  ///
  /// Like a Laravel prunable model: delete records older than N days.
  Future<void> enforceRetention() async {
    final backups = await listBackups();
    if (backups.length <= maxBackups) return;

    // Delete everything beyond the first `maxBackups` entries (newest first).
    final toDelete = backups.sublist(maxBackups);
    for (final file in toDelete) {
      await file.delete();
    }
  }

  /// Zero-pad a number to 2 digits (e.g., 5 → "05").
  /// Like str_pad($n, 2, '0', STR_PAD_LEFT) in PHP.
  String _pad(int n) => n.toString().padLeft(2, '0');
}
