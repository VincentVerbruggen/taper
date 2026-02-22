import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/backup_providers.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/trackables/add_trackable_screen.dart';
import 'package:taper/screens/trackables/edit_trackable_screen.dart';
import 'package:taper/services/backup_service.dart';
import 'package:taper/services/notification_service.dart';

/// Settings screen — the 3rd tab in the bottom nav.
///
/// Combines trackable management (previously a separate tab) with app settings.
/// Layout: Trackables section → Settings section → Data section.
///
/// ConsumerStatefulWidget because we need both:
///   - Riverpod providers for reactive data (trackables, settings)
///   - Local state for trackable list reorder callbacks
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
    final trackablesAsync = ref.watch(trackablesProvider);
    final boundaryHour = ref.watch(dayBoundaryHourProvider);
    final themeMode = ref.watch(themeModeProvider);
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

            // =================================================================
            // TRACKABLES SECTION
            // Moved from the old Trackables tab into Settings.
            // Uses a ReorderableListView with shrinkWrap so it fits inside the
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

            const Divider(height: 32),

            // =================================================================
            // SETTINGS SECTION
            // =================================================================

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

  /// Builds the trackable list as a ReorderableListView with shrinkWrap.
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

    return ReorderableListView.builder(
      shrinkWrap: true, // Only take the height needed (don't expand to fill)
      physics: const NeverScrollableScrollPhysics(), // Let outer ListView scroll
      itemCount: trackables.length,
      onReorder: (oldIndex, newIndex) =>
          _onReorder(trackables, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final trackable = trackables[index];
        return _TrackableListItem(
          key: ValueKey(trackable.id),
          trackable: trackable,
          index: index,
          onTap: () => _editTrackable(trackable),
          onTogglePin: () => _togglePin(trackable),
        );
      },
    );
  }

  // ===========================================================================
  // TRACKABLE ACTIONS (moved from TrackablesScreen)
  // ===========================================================================

  /// Handle drag-to-reorder.
  void _onReorder(List<Trackable> trackables, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final ids = trackables.map((t) => t.id).toList();
    final movedId = ids.removeAt(oldIndex);
    ids.insert(newIndex, movedId);
    ref.read(databaseProvider).reorderTrackables(ids);
  }

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
// Same design as the old TrackablesScreen's _TrackableListItem but wrapped
// in the unified Card pattern (Padding > Card > ListTile).
// =============================================================================

/// A single trackable in the settings list — Card-wrapped with drag handle,
/// color dot, and pin button. Tapping the card opens the edit screen.
///
/// All management actions (duplicate, hide/show, delete) live in the edit screen.
/// ConsumerWidget so it can watch pinnedTrackableIdProvider for pin icon state.
class _TrackableListItem extends ConsumerWidget {
  final Trackable trackable;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;

  const _TrackableListItem({
    super.key,
    required this.trackable,
    required this.index,
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
            // Leading: drag handle + color dot.
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle, size: 24),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Color(trackable.color).withAlpha(isHidden ? 77 : 255),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
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
            // Trailing: pin button only. All other actions moved to edit screen.
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
