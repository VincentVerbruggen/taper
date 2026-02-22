import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:taper/providers/backup_providers.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/services/backup_service.dart';

/// Settings screen — the 4th tab in the bottom nav.
///
/// Contains app preferences (day boundary) and data management
/// (export, import, auto-backup).
///
/// Like a Laravel settings page (/settings/general) with form fields
/// that persist to the database (here: SharedPreferences).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boundaryHour = ref.watch(dayBoundaryHourProvider);
    final autoBackupEnabled = ref.watch(autoBackupEnabledProvider);
    final lastBackupTime = ref.watch(lastBackupTimeProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),

            // --- Day boundary setting ---
            // ListTile with a dropdown on the trailing side.
            // The dropdown offers hours 0–12 (midnight to noon), formatted as "05:00".
            ListTile(
              title: const Text('Day starts at'),
              subtitle: const Text(
                'Doses logged before this time count as the previous day',
              ),
              trailing: DropdownButton<int>(
                value: boundaryHour,
                // Generate items for hours 0 through 12.
                // Formatted as "HH:00" — e.g., 5 → "05:00", 0 → "00:00".
                items: List.generate(13, (hour) {
                  final label = '${hour.toString().padLeft(2, '0')}:00';
                  return DropdownMenuItem<int>(
                    value: hour,
                    child: Text(label),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(dayBoundaryHourProvider.notifier).setHour(value);
                  }
                },
              ),
            ),

            const Divider(height: 32),

            // --- Data section header ---
            Text(
              'Data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            // --- Auto-backup toggle ---
            // SwitchListTile = a ListTile with a built-in Switch on the trailing side.
            // Like a toggle input in a Livewire component that auto-saves on change.
            SwitchListTile(
              title: const Text('Daily auto-backup'),
              subtitle: Text(
                lastBackupTime != null
                    ? 'Last backup: ${_formatDateTime(lastBackupTime)}'
                    : 'Never backed up',
              ),
              value: autoBackupEnabled,
              onChanged: (value) {
                ref.read(autoBackupEnabledProvider.notifier).setEnabled(value);
              },
            ),

            // --- Export button ---
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Export database'),
              subtitle: const Text('Share your database file as a backup'),
              onTap: () => _handleExport(context, ref),
            ),

            // --- Import button ---
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Import database'),
              subtitle: const Text('Replace all data from a backup file'),
              onTap: () => _handleImport(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  /// Export the database via the native share sheet.
  ///
  /// Flow: checkpoint WAL → copy to temp → open share sheet.
  /// Like generating a download link in a Laravel controller:
  ///   return response()->download(storage_path('taper.sqlite'))
  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    // Show a loading indicator while preparing the export.
    _showLoadingDialog(context, 'Preparing export...');

    try {
      final db = ref.read(databaseProvider);
      final backup = BackupService.instance;

      // Flush WAL writes into the main file before copying.
      await db.checkpointWal();

      // Copy DB to temp with a timestamped filename.
      final exportFile = await backup.prepareExportFile();

      // Dismiss the loading dialog before opening the share sheet.
      if (context.mounted) Navigator.of(context).pop();

      // Open the native share sheet with the file.
      // On Android: "Share via" → save to Files, email, Drive, etc.
      // On iOS: share sheet with AirDrop, save to Files, etc.
      // Like a "Download" button that opens the browser's save dialog.
      await Share.shareXFiles([XFile(exportFile.path)]);
    } catch (e) {
      // Dismiss loading dialog if still open.
      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  /// Import a database from a user-picked file.
  ///
  /// Flow: confirm → pick file → validate → close DB → replace → refresh providers.
  /// Like a Laravel controller action that processes an uploaded file:
  ///   $request->file('backup')->storeAs('/', 'taper.sqlite')
  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    // First confirmation: warn the user this is destructive.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import database'),
        content: const Text(
          'This will replace ALL your current data with the imported file. '
          'This cannot be undone.\n\n'
          'Consider exporting a backup first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Choose file'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Open the file picker. Allow any file type because .sqlite isn't a
    // standard MIME type that file pickers recognize.
    // Like <input type="file"> in HTML — the user picks what to upload.
    final result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result == null || result.files.isEmpty || !context.mounted) return;

    final pickedPath = result.files.single.path;
    if (pickedPath == null || !context.mounted) return;

    // Validate the file before doing anything destructive.
    final isValid = await BackupService.instance.isValidSqliteFile(pickedPath);
    if (!isValid) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid file — not a valid SQLite database.'),
          ),
        );
      }
      return;
    }

    // Show progress while replacing the database.
    if (!context.mounted) return;
    _showLoadingDialog(context, 'Importing database...');

    try {
      // Close the current database connection BEFORE replacing the file.
      // This releases the file handle so we can overwrite it safely.
      // Like calling DB::disconnect() before swapping the database file.
      final db = ref.read(databaseProvider);
      await db.close();

      // Replace the database file on disk.
      final success = await BackupService.instance.importDatabase(pickedPath);

      if (!success) {
        if (context.mounted) Navigator.of(context).pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Import failed — invalid database file.')),
          );
        }
        return;
      }

      // Force all providers to rebuild with the new database.
      // Incrementing the generation counter invalidates databaseProvider,
      // which cascades to all stream providers (trackables, doses, etc.).
      // Like clearing Laravel's entire cache: Artisan::call('cache:clear')
      ref.read(databaseGenerationProvider.notifier).increment();

      // Dismiss loading dialog.
      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database imported successfully!')),
        );
      }
    } catch (e) {
      // If something went wrong, still try to recover by rebuilding the DB.
      ref.read(databaseGenerationProvider.notifier).increment();

      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    }
  }

  /// Show a simple loading dialog with a spinner and message.
  /// Like a "please wait" overlay in a web app.
  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  /// Format a DateTime for display in the settings subtitle.
  /// Shows "Today 14:30" or "Feb 22, 14:30" depending on whether it's today.
  /// Like Carbon::format('M j, H:i') in Laravel.
  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;

    final time = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';

    if (isToday) return 'Today $time';

    // Month abbreviations — Dart doesn't have built-in month names without intl.
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, $time';
  }
}
