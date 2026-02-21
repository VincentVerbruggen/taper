import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/data/decay_model.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/trackables/add_trackable_screen.dart';
import 'package:taper/screens/trackables/edit_trackable_screen.dart';
import 'package:taper/services/notification_service.dart';

/// TrackablesScreen = the full CRUD screen for managing trackables.
///
/// ConsumerStatefulWidget = a StatefulWidget that can access Riverpod providers.
/// "Consumer" means "I consume providers" (dependency injection).
/// Like a Livewire component with both local state ($showModal) AND
/// injected dependencies ($this->trackableService).
class TrackablesScreen extends ConsumerStatefulWidget {
  const TrackablesScreen({super.key});

  @override
  ConsumerState<TrackablesScreen> createState() => _TrackablesScreenState();
}

class _TrackablesScreenState extends ConsumerState<TrackablesScreen> {
  @override
  Widget build(BuildContext context) {
    final trackablesAsync = ref.watch(trackablesProvider);

    return Scaffold(
      // FAB navigates to the add trackable screen.
      floatingActionButton: FloatingActionButton(
        heroTag: 'addTrackableFab',
        onPressed: () => _addTrackable(),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: false,
        child: trackablesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (trackables) => _buildTrackablesList(trackables),
        ),
      ),
    );
  }

  Widget _buildTrackablesList(List<Trackable> trackables) {
    // Empty state — show a hint when no trackables.
    if (trackables.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Trackables',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 48),
          const Center(
            child: Text('No trackables yet. Tap + to add one.'),
          ),
        ],
      );
    }

    // ReorderableListView with a header. The header is a non-reorderable
    // item at the top. Since ReorderableListView needs keys on all children,
    // we use a Column wrapping approach: header is outside in a Column.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- "Trackables" heading ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Trackables',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),

        // --- Reorderable trackable list ---
        Expanded(
          child: ReorderableListView.builder(
            itemCount: trackables.length,
            onReorder: (oldIndex, newIndex) =>
                _onReorder(trackables, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final trackable = trackables[index];

              return _TrackableListItem(
                key: ValueKey(trackable.id),
                trackable: trackable,
                index: index,
                onEdit: () => _editTrackable(trackable),
                onTogglePin: () => _togglePin(trackable),
                onToggleVisibility: () => _toggleVisibility(trackable),
                onDelete: () => _deleteTrackable(trackable),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Handle drag-to-reorder.
  void _onReorder(List<Trackable> trackables, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final ids = trackables.map((t) => t.id).toList();
    final movedId = ids.removeAt(oldIndex);
    ids.insert(newIndex, movedId);
    ref.read(databaseProvider).reorderTrackables(ids);
  }

  // --- Mutation methods ---

  /// Navigate to the edit screen for this trackable.
  /// Like clicking a row in a Laravel resource table -> GET /trackables/{id}/edit.
  void _editTrackable(Trackable trackable) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditTrackableScreen(trackable: trackable),
      ),
    );
  }

  /// Toggle pin: pin this trackable to a persistent notification, or unpin it.
  ///
  /// When pinning, requests notification permission first (Android 13+ requires it).
  /// Only one trackable can be pinned at a time — pinning a new one stops the old.
  void _togglePin(Trackable trackable) async {
    final notificationService = NotificationService.instance;
    final pinnedId = ref.read(pinnedTrackableIdProvider);

    if (pinnedId == trackable.id) {
      // Already pinned -> unpin.
      await notificationService.stopTracking();
      ref.read(pinnedTrackableIdProvider.notifier).unpin();
    } else {
      // Not pinned -> request permission and pin.
      final granted = await notificationService.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification permission required to pin')),
          );
        }
        return;
      }

      final db = ref.read(databaseProvider);
      await notificationService.startTracking(trackable, db);
      ref.read(pinnedTrackableIdProvider.notifier).pin(trackable.id);
    }
  }

  /// Toggle visibility of a trackable (show/hide in the Log form dropdown).
  /// Like toggling a `is_visible` boolean column: UPDATE trackables SET is_visible = !is_visible WHERE id = ?
  void _toggleVisibility(Trackable trackable) {
    final db = ref.read(databaseProvider);
    db.updateTrackable(trackable.id, isVisible: Value(!trackable.isVisible));
  }

  /// Delete a trackable after showing a confirmation dialog.
  /// Like Laravel's destroy: DELETE /trackables/{id} with a "are you sure?" modal.
  void _deleteTrackable(Trackable trackable) async {
    // Show confirmation dialog before deleting — destructive action needs user consent.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trackable'),
        content: Text('Delete "${trackable.name}"? This will also delete all dose logs for this trackable.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final db = ref.read(databaseProvider);
      await db.deleteTrackable(trackable.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${trackable.name} deleted')),
        );
      }
    }
  }

  /// Navigate to the add trackable screen.
  /// Like clicking "Create" in a Laravel resource → GET /trackables/create.
  void _addTrackable() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTrackableScreen()),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets — like Blade partials (trackables/_item.blade.php)
// ---------------------------------------------------------------------------

/// A single trackable in the list — expressive design with drag handle,
/// color dot, pin button, and three-dots menu (edit / show-hide / delete).
///
/// Layout:
/// ┌──────────────────────────────────────────────────────┐
/// │  ≡  ● Caffeine                         📌    ⋮      │
/// │        mg · half-life: 5.0h                          │
/// └──────────────────────────────────────────────────────┘
///
/// ConsumerWidget so it can watch pinnedTrackableIdProvider for pin icon state.
class _TrackableListItem extends ConsumerWidget {
  final Trackable trackable;
  // Index in the list — needed by ReorderableDragStartListener to know
  // which item to pick up when the user starts dragging.
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleVisibility;
  final VoidCallback onDelete;

  const _TrackableListItem({
    super.key,
    required this.trackable,
    required this.index,
    required this.onEdit,
    required this.onTogglePin,
    required this.onToggleVisibility,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHidden = !trackable.isVisible;
    // Watch pinned state to show filled/outlined pin icon for this trackable.
    final pinnedId = ref.watch(pinnedTrackableIdProvider);
    final isPinned = pinnedId == trackable.id;

    return Column(
      children: [
        ListTile(
          // Leading: drag handle + color dot in a row.
          // ReorderableDragStartListener wraps the drag handle icon so that
          // touching it initiates a drag-to-reorder (like a ≡ grip handle).
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle — initiates reorder when user long-presses / drags.
              // ReorderableDragStartListener is the built-in Flutter widget that
              // connects a child widget to the ReorderableListView's drag system.
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle, size: 24),
              ),
              const SizedBox(width: 8),
              // Color dot — visual identifier for the trackable's assigned color.
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
          subtitle: Text(
            _buildSubtitle(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(
                isHidden ? 77 : 179,
              ),
            ),
          ),
          // Trailing: pin button + three-dots menu.
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pin/Unpin — pins this trackable to a persistent notification
              // for rapid dose logging (party mode). Filled icon = pinned.
              IconButton(
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
              // Three-dots menu (⋮) — like a kebab menu in a web UI.
              // PopupMenuButton shows a dropdown with Edit, Show/Hide, Delete.
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                tooltip: 'More options',
                onSelected: (value) {
                  // Route menu selection to the appropriate callback.
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'visibility':
                      onToggleVisibility();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  // Edit — navigates to the edit screen for this trackable.
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                      // Dense so the menu items aren't too tall.
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  // Show / Hide — toggles isVisible flag.
                  PopupMenuItem(
                    value: 'visibility',
                    child: ListTile(
                      leading: Icon(
                        isHidden ? Icons.visibility : Icons.visibility_off,
                      ),
                      title: Text(isHidden ? 'Show' : 'Hide'),
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  // Delete — destructive action, shown in red.
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Delete',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  /// Build the subtitle text showing unit and decay model info.
  ///   - exponential: "mg · half-life: 5.0h"
  ///   - linear: "ml · elimination: 9.0 ml/h"
  ///   - none: "ml"
  String _buildSubtitle() {
    final model = DecayModel.fromString(trackable.decayModel);
    return switch (model) {
      DecayModel.exponential => trackable.halfLifeHours != null
          ? '${trackable.unit} \u00B7 half-life: ${trackable.halfLifeHours}h'
          : trackable.unit,
      DecayModel.linear => trackable.eliminationRate != null
          ? '${trackable.unit} \u00B7 elimination: ${trackable.eliminationRate} ${trackable.unit}/h'
          : trackable.unit,
      DecayModel.none => trackable.unit,
    };
  }
}
