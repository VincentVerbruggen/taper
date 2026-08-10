import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/backup_providers.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/trackables/add_trackable_screen.dart';
import 'package:taper/screens/trackables/edit_trackable_screen.dart';
import 'package:taper/services/backup_service.dart';
import 'package:taper/services/notification_service.dart';
import 'package:taper/services/storage_permission.dart';

/// Settings screen — the 3rd tab in the bottom nav.
///
/// Combines trackable management (previously a separate tab) with app settings.
/// Layout: Trackables section → Settings section → Data section.
///
/// ConsumerStatefulWidget because we need:
///   - Riverpod providers for reactive data (trackables, settings)
///
/// Like a Laravel settings page that also embeds an inline CRUD list
/// (imagine a "Manage categories" section above general settings).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    // Active (non-archived) trackables for the main list, and archived ones
    // for the collapsible "Archived" section below it.
    final trackablesAsync = ref.watch(activeTrackablesProvider);
    final archivedTrackablesAsync = ref.watch(archivedTrackablesProvider);
    final boundaryHour = ref.watch(dayBoundaryHourProvider);
    final themeMode = ref.watch(themeModeProvider);
    final autoBackupEnabled = ref.watch(autoBackupEnabledProvider);
    final lastBackupTime = ref.watch(lastBackupTimeProvider);
    final externalBackupFolder = ref.watch(externalBackupFolderProvider);
    final lastExternalBackupTime = ref.watch(lastExternalBackupTimeProvider);
    final lastBackupError = ref.watch(lastBackupErrorProvider);

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

            // =================================================================
            // TRACKABLES SECTION
            // Moved from the old Trackables tab into Settings.
            // Uses a ListView with shrinkWrap so it fits inside the
            // outer ListView without needing its own scroll physics.
            // =================================================================
            Text(
              'Trackables',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            // Trackable list content — loading / empty / populated.
            trackablesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
              data: (trackables) => _buildTrackablesSection(trackables),
            ),

            const SizedBox(height: 8),

            // "Add trackable" button — replaces the FAB since we're inside a scroll.
            // Inline button instead of floating: better UX inside a settings list.
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add trackable'),
              onTap: _addTrackable,
            ),

            // --- Archived trackables section ---
            // Only shown when there's at least one archived trackable. Collapsed
            // by default (ExpansionTile) so it stays out of the way. Tapping a
            // row opens the edit screen where the trackable can be unarchived.
            archivedTrackablesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (archived) => _buildArchivedSection(archived),
            ),

            const Divider(height: 32),

            // =================================================================
            // APPEARANCE SECTION
            // =================================================================
            Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            // --- Day boundary setting ---
            ListTile(
              title: const Text('Day starts at'),
              subtitle: const Text(
                'Doses logged before this time count as the previous day',
              ),
              trailing: DropdownButton<int>(
                value: boundaryHour,
                // Generate items for hours 0 through 12.
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

            // --- Theme mode setting ---
            // Dropdown with Auto/Light/Dark — same pattern as day boundary.
            // Like a CSS prefers-color-scheme toggle in a settings panel.
            ListTile(
              title: const Text('Theme'),
              subtitle: const Text('Control light/dark appearance'),
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('Auto'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).setMode(value);
                  }
                },
              ),
            ),

            // --- Performance overlay toggle ---
            // Shows Flutter's built-in FPS graphs (UI thread + raster thread).
            // Only meaningful in profile builds — like Chrome DevTools FPS meter.
            SwitchListTile(
              title: const Text('Performance overlay'),
              subtitle: const Text(
                'Show FPS graphs (use with flutter run --profile)',
              ),
              value: ref.watch(perfOverlayProvider),
              onChanged: (_) {
                ref.read(perfOverlayProvider.notifier).toggle();
              },
            ),

            const Divider(height: 32),

            // =================================================================
            // DATA SECTION
            // =================================================================
            Text(
              'Data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            // --- Auto-backup toggle ---
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

            // --- External backup folder picker ---
            // Optional mirror destination for each auto-backup. If unset,
            // backups stay in the app's internal docs dir only. If set,
            // we copy each daily backup to this folder too (best-effort).
            //
            // Disabled when auto-backup itself is off — like a sub-setting
            // that only makes sense when the parent toggle is on.
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('External backup folder'),
              // Show the path plus a status line so a failed mirror is visible
              // (this is what was silently broken before). Column instead of a
              // plain string because we colour the error line red.
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    externalBackupFolder ??
                        'Not set — backups are stored in app storage only',
                  ),
                  if (externalBackupFolder != null && lastBackupError != null)
                    Text(
                      lastBackupError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  else if (externalBackupFolder != null)
                    Text(
                      lastExternalBackupTime != null
                          ? 'Last mirrored: ${_formatDateTime(lastExternalBackupTime)}'
                          : 'Not mirrored yet — happens on the next data change',
                    ),
                ],
              ),
              enabled: autoBackupEnabled,
              trailing: externalBackupFolder != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear external folder',
                      onPressed: () => ref
                          .read(externalBackupFolderProvider.notifier)
                          .setFolder(null),
                    )
                  : null,
              onTap: autoBackupEnabled ? _pickExternalBackupFolder : null,
            ),

            // --- All-files-access grant prompt ---
            // Only shown when a folder is configured but we lack the special
            // "All files access" grant (e.g. the folder pref was restored from
            // Android's auto-backup after a reinstall, but the grant wasn't).
            // Without it, mirror writes fail with a cryptic OS "operation not
            // permitted" error. This gives the user a one-tap way to fix it.
            if (autoBackupEnabled && externalBackupFolder != null)
              _buildStorageAccessTile(),

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

  // ===========================================================================
  // TRACKABLES SECTION BUILD
  // ===========================================================================

  /// Builds the trackable list as a simple ListView.
  ///
  /// shrinkWrap + NeverScrollableScrollPhysics makes it behave like a Column
  /// inside the outer ListView — it takes only the height it needs and doesn't
  /// scroll independently. Like a nested <div> with no overflow scroll.
  Widget _buildTrackablesSection(List<Trackable> trackables) {
    if (trackables.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('No trackables yet. Add one below.')),
      );
    }

    return ListView.builder(
      shrinkWrap: true, // Only take the height needed (don't expand to fill)
      physics: const NeverScrollableScrollPhysics(), // Let outer ListView scroll
      itemCount: trackables.length,
      itemBuilder: (context, index) {
        final trackable = trackables[index];
        return _TrackableListItem(
          key: ValueKey(trackable.id),
          trackable: trackable,
          onTap: () => _editTrackable(trackable),
          onTogglePin: () => _togglePin(trackable),
        );
      },
    );
  }

  /// Builds the collapsible "Archived" section listing archived trackables.
  ///
  /// Returns an empty widget when nothing is archived, so the section only
  /// appears once the user has archived at least one trackable. Uses an
  /// ExpansionTile (collapsed by default) — like an HTML `details`/`summary`
  /// element that keeps rarely-used items tucked away but reachable.
  Widget _buildArchivedSection(List<Trackable> archived) {
    if (archived.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Theme(
        // Remove the default ExpansionTile dividers so it blends with the list.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.archive_outlined),
          title: Text('Archived (${archived.length})'),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: archived
              .map(
                (trackable) => _ArchivedTrackableListItem(
                  key: ValueKey('archived_${trackable.id}'),
                  trackable: trackable,
                  onTap: () => _editTrackable(trackable),
                  onUnarchive: () => _unarchive(trackable),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  /// Restore an archived trackable so it reappears everywhere (log dropdown,
  /// dashboard, analysis). Shows a confirmation snackbar afterwards.
  Future<void> _unarchive(Trackable trackable) async {
    await ref
        .read(databaseProvider)
        .setTrackableArchived(trackable.id, false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          showCloseIcon: true,
          content: Text('Restored "${trackable.name}"'),
        ),
      );
    }
  }

  // ===========================================================================
  // TRACKABLE ACTIONS (moved from TrackablesScreen)
  // ===========================================================================

  /// Navigate to the edit screen for this trackable.
  void _editTrackable(Trackable trackable) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditTrackableScreen(trackable: trackable),
      ),
    );
  }

  /// Toggle pin: pin this trackable to a persistent notification, or unpin it.
  void _togglePin(Trackable trackable) async {
    final notificationService = NotificationService.instance;
    final pinnedId = ref.read(pinnedTrackableIdProvider);

    if (pinnedId == trackable.id) {
      await notificationService.stopTracking();
      ref.read(pinnedTrackableIdProvider.notifier).unpin();
    } else {
      final granted = await notificationService.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              showCloseIcon: true,
              content: Text('Notification permission required to pin'),
            ),
          );
        }
        return;
      }

      final db = ref.read(databaseProvider);
      await notificationService.startTracking(trackable, db);
      ref.read(pinnedTrackableIdProvider.notifier).pin(trackable.id);
    }
  }

  /// Navigate to the add trackable screen.
  void _addTrackable() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTrackableScreen()),
    );
  }

  // ===========================================================================
  // DATA MANAGEMENT ACTIONS
  // ===========================================================================

  /// A warning tile prompting the user to grant "All files access", shown only
  /// when we've confirmed we DON'T have it. While the async check is still
  /// loading we assume granted (?? true) so we don't flash a warning that
  /// immediately disappears.
  Widget _buildStorageAccessTile() {
    // asData is non-null only once the check has produced a value; treat the
    // still-loading state as "granted" so no warning flashes prematurely.
    final granted =
        ref.watch(storagePermissionGrantedProvider).asData?.value ?? true;
    if (granted) return const SizedBox.shrink();

    final errorColor = Theme.of(context).colorScheme.error;
    return ListTile(
      leading: Icon(Icons.warning_amber, color: errorColor),
      title: const Text("Grant 'All files access'"),
      subtitle: const Text(
        'Required to write backups to your folder. Tap to grant.',
      ),
      onTap: _grantStorageAccess,
    );
  }

  /// Request the "All files access" grant, then re-check so the UI updates.
  Future<void> _grantStorageAccess() async {
    final granted = await StoragePermission.request();
    // Force the status provider to re-run its check so the warning tile
    // disappears (or stays) based on the new state.
    ref.invalidate(storagePermissionGrantedProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        showCloseIcon: true,
        content: Text(
          granted
              ? 'Storage access granted — backups will mirror to your folder.'
              : "Still not granted. Enable 'All files access' for Taper in "
                  'system settings (Special app access → All files access).',
        ),
        action: granted
            ? null
            : SnackBarAction(label: 'Settings', onPressed: openAppSettings),
      ),
    );
  }

  /// Open the system folder picker and save the chosen path as the
  /// external backup mirror destination. A null result = user cancelled.
  ///
  /// Writing raw files into a shared-storage folder needs the "All files
  /// access" grant on Android 11+, so we (1) ensure that permission, then
  /// (2) do a real test write before saving. That way the user finds out
  /// immediately if the folder won't work, instead of discovering days later
  /// that nothing was ever mirrored — which is exactly what was happening.
  Future<void> _pickExternalBackupFolder() async {
    final picked = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose external backup folder',
    );
    if (picked == null) return; // User cancelled.

    // 1. Make sure we can write to shared storage at all.
    if (!await StoragePermission.isGranted()) {
      final granted = await StoragePermission.request();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            showCloseIcon: true,
            content: const Text(
              'Storage permission denied. Enable "All files access" for Taper '
              'in system settings, then pick the folder again.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
        return;
      }
    }

    // 2. Prove we can actually create a file there before trusting it.
    final writable = await BackupService.instance.canWriteToFolder(picked);
    if (!writable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          showCloseIcon: true,
          content: Text(
            "Can't write to that folder ($picked). Pick a different one, e.g. "
            'a folder under Documents or Download.',
          ),
        ),
      );
      return;
    }

    await ref.read(externalBackupFolderProvider.notifier).setFolder(picked);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          showCloseIcon: true,
          content: Text('External backup folder set: $picked'),
        ),
      );
    }
  }

  /// Export the database via the native share sheet.
  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    _showLoadingDialog(context, 'Preparing export...');

    try {
      final db = ref.read(databaseProvider);
      final backup = BackupService.instance;

      await db.checkpointWal();
      final exportFile = await backup.prepareExportFile();

      if (context.mounted) Navigator.of(context).pop();

      await Share.shareXFiles([XFile(exportFile.path)]);
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            showCloseIcon: true,
            content: Text('Export failed: $e'),
          ),
        );
      }
    }
  }

  /// Import a database from a user-picked file.
  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
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

    final result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result == null || result.files.isEmpty || !context.mounted) return;

    final pickedPath = result.files.single.path;
    if (pickedPath == null || !context.mounted) return;

    final isValid = await BackupService.instance.isValidSqliteFile(pickedPath);
    if (!isValid) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            showCloseIcon: true,
            content: Text('Invalid file — not a valid SQLite database.'),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    _showLoadingDialog(context, 'Importing database...');

    try {
      final db = ref.read(databaseProvider);
      await db.close();

      final success = await BackupService.instance.importDatabase(pickedPath);

      if (!success) {
        if (context.mounted) Navigator.of(context).pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              showCloseIcon: true,
              content: Text('Import failed — invalid database file.'),
            ),
          );
        }
        return;
      }

      ref.read(databaseGenerationProvider.notifier).increment();

      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            showCloseIcon: true,
            content: Text('Database imported successfully!'),
          ),
        );
      }
    } catch (e) {
      ref.read(databaseGenerationProvider.notifier).increment();

      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            showCloseIcon: true,
            content: Text('Import error: $e'),
          ),
        );
      }
    }
  }

  /// Show a simple loading dialog with a spinner and message.
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
  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;

    final time = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';

    if (isToday) return 'Today $time';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, $time';
  }
}

// =============================================================================
// TRACKABLE LIST ITEM — inline widget for the trackable list in settings.
// =============================================================================

/// A single trackable in the settings list — Card-wrapped with color dot,
/// and pin button. Tapping the card opens the edit screen.
///
/// ConsumerWidget so it can watch pinnedTrackableIdProvider for pin icon state.
class _TrackableListItem extends ConsumerWidget {
  final Trackable trackable;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;

  const _TrackableListItem({
    super.key,
    required this.trackable,
    required this.onTap,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHidden = !trackable.isVisible;
    final pinnedId = ref.watch(pinnedTrackableIdProvider);
    final isPinned = pinnedId == trackable.id;

    // Unified card pattern: Card(shape: RoundedRectangleBorder(12)) > InkWell > ListTile
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Card(
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: shape,
          // Tapping the card opens the edit screen — all management actions
          // (duplicate, hide/show, delete) are accessible from there.
          onTap: onTap,
          child: ListTile(
            // Leading: color dot. Drag handle removed to simplify UI.
            leading: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Color(trackable.color).withAlpha(isHidden ? 77 : 255),
                shape: BoxShape.circle,
              ),
            ),
            title: Text(
              trackable.name,
              style: isHidden
                  ? TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(128),
                    )
                  : null,
            ),
            // Trailing: pin button only.
            trailing: IconButton(
              icon: Icon(
                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 20,
                color: isPinned
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: onTogglePin,
              tooltip: isPinned ? 'Unpin from notification' : 'Pin to notification',
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ),
    );
  }
}

/// A single archived trackable row in the Settings "Archived" section.
///
/// Tapping the row opens the edit screen (where it can also be unarchived);
/// the trailing "unarchive" icon is a one-tap shortcut to restore it directly.
/// Rendered dimmed to signal its inactive state.
class _ArchivedTrackableListItem extends StatelessWidget {
  final Trackable trackable;
  final VoidCallback onTap;
  final VoidCallback onUnarchive;

  const _ArchivedTrackableListItem({
    super.key,
    required this.trackable,
    required this.onTap,
    required this.onUnarchive,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      // Dimmed color dot to match the "inactive" feel of the section.
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: Color(trackable.color).withAlpha(102),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        trackable.name,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.unarchive_outlined, size: 20),
        tooltip: 'Restore',
        onPressed: onUnarchive,
        visualDensity: VisualDensity.compact,
      ),
      onTap: onTap,
    );
  }
}
