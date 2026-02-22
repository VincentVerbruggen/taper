import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/dashboard_widget_type.dart';
import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/dashboard/widgets/daily_totals_card.dart';
import 'package:taper/screens/dashboard/widgets/enhanced_decay_card.dart';
import 'package:taper/screens/dashboard/widgets/taper_progress_card.dart';
import 'package:taper/screens/dashboard/widgets/trackable_card.dart';

/// Dashboard tab — shows configurable widget cards for trackables.
///
/// Each widget is an independent card that loads its own data. The dashboard
/// layout is controlled by the DashboardWidgets table, decoupled from
/// trackable visibility (which now only controls the log form dropdown).
///
/// Always shows "today" (live data). Historical date browsing lives in the
/// per-trackable detail view (TrackableLogScreen) behind a calendar icon.
///
/// Includes an edit mode for reordering/deleting/adding widgets.
///
/// ConsumerStatefulWidget because we need local state for edit mode toggle.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  /// Whether the user is in edit mode (reorder/delete/add widgets).
  /// Resets naturally when navigating away — no provider needed.
  bool _isEditMode = false;

  @override
  Widget build(BuildContext context) {
    final widgetsAsync = ref.watch(dashboardWidgetsProvider);
    final trackablesAsync = ref.watch(trackablesProvider);

    return widgetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (widgets) {
        // Also wait for trackables so we have names/colors for edit mode labels.
        return trackablesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (trackables) {
            return SafeArea(
              bottom: false,
              child: _isEditMode
                  ? _buildEditMode(context, widgets, trackables)
                  : _buildNormalMode(context, widgets),
            );
          },
        );
      },
    );
  }

  /// Normal mode: full-size widget cards with a small edit toggle at the top.
  Widget _buildNormalMode(
    BuildContext context,
    List<DashboardWidget> widgets,
  ) {
    // Empty state: no dashboard widgets configured.
    if (widgets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No dashboard widgets.\nTap the edit icon to add one.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => setState(() => _isEditMode = true),
                tooltip: 'Edit dashboard',
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      // +1 for the edit toggle row at index 0.
      itemCount: widgets.length + 1,
      itemBuilder: (context, index) {
        // First item = "Dashboard" heading with edit toggle on the right.
        // Matches the pattern used by Log, Trackables, and Settings tabs.
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dashboard',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit dashboard',
                  onPressed: () => setState(() => _isEditMode = true),
                ),
              ],
            ),
          );
        }

        // Render the appropriate widget card based on type.
        final widget = widgets[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildWidgetCard(widget),
        );
      },
    );
  }

  /// Renders a widget card based on its type.
  Widget _buildWidgetCard(DashboardWidget widget) {
    final type = DashboardWidgetType.fromString(widget.type);
    return switch (type) {
      DashboardWidgetType.decayCard => TrackableCard(
          trackableId: widget.trackableId!,
        ),
      DashboardWidgetType.taperProgress => TaperProgressCard(
          trackableId: widget.trackableId!,
        ),
      DashboardWidgetType.dailyTotals => DailyTotalsCard(
          trackableId: widget.trackableId!,
        ),
      DashboardWidgetType.enhancedDecayCard => EnhancedDecayCard(
          trackableId: widget.trackableId!,
        ),
    };
  }

  /// Edit mode: header with done button + reorderable labels + "Add Widget".
  Widget _buildEditMode(
    BuildContext context,
    List<DashboardWidget> widgets,
    List<Trackable> trackables,
  ) {
    // Build a trackable lookup map for quick name/color access.
    final trackableMap = {for (final t in trackables) t.id: t};

    return Column(
      children: [
        // Header with done button.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Done editing',
              onPressed: () => setState(() => _isEditMode = false),
            ),
          ),
        ),

        // Reorderable list of widget labels.
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // +1 for the "Add Widget" button at the end.
            itemCount: widgets.length + 1,
            onReorder: (oldIndex, newIndex) {
              // Ignore reorder involving the "Add Widget" button.
              if (oldIndex >= widgets.length || newIndex > widgets.length) {
                return;
              }
              // ReorderableListView passes newIndex relative to the list
              // BEFORE removal. When moving down, adjust by -1.
              if (newIndex > oldIndex) newIndex--;
              final ids = widgets.map((w) => w.id).toList();
              final movedId = ids.removeAt(oldIndex);
              ids.insert(newIndex, movedId);
              ref.read(databaseProvider).reorderDashboardWidgets(ids);
            },
            itemBuilder: (context, index) {
              // Last item = "Add Widget" button (not draggable).
              if (index >= widgets.length) {
                return ReorderableDragStartListener(
                  key: const ValueKey('add_widget_button'),
                  index: index,
                  enabled: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddWidgetDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Widget'),
                    ),
                  ),
                );
              }

              final widget = widgets[index];
              final trackable = widget.trackableId != null
                  ? trackableMap[widget.trackableId]
                  : null;
              final widgetType = DashboardWidgetType.fromString(widget.type);
              final color =
                  trackable != null ? Color(trackable.color) : Colors.grey;
              final name = trackable?.name ?? 'Unknown';

              return Padding(
                key: ValueKey(widget.id),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    title: Text(name),
                    subtitle: Text(widgetType.displayName),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Remove widget',
                      onPressed: () {
                        ref
                            .read(databaseProvider)
                            .deleteDashboardWidget(widget.id);
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Two-step "Add Widget" dialog:
  /// 1. Pick widget type (Decay Card or Taper Progress)
  /// 2. Pick which trackable to show
  void _showAddWidgetDialog(BuildContext context) async {
    final db = ref.read(databaseProvider);

    // Step 1: Pick widget type.
    final type = await showDialog<DashboardWidgetType>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add Widget'),
        children: DashboardWidgetType.values.map((t) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, t),
            child: Text(t.displayName),
          );
        }).toList(),
      ),
    );
    if (type == null || !mounted) return;

    // Step 2: Pick a trackable.
    final trackables = ref.read(trackablesProvider).value ?? [];
    if (trackables.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No trackables available.')),
        );
      }
      return;
    }

    // For taper_progress, filter to only trackables with active taper plans.
    // Query the DB directly (not the cached provider) so we always get fresh
    // data — e.g., if the user just created a taper plan and came back.
    List<Trackable> eligibleTrackables;
    if (type == DashboardWidgetType.taperProgress) {
      final withPlans = <Trackable>[];
      for (final t in trackables) {
        final plan = await db.getActiveTaperPlan(t.id);
        if (plan != null) {
          withPlans.add(t);
        }
      }
      if (withPlans.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No trackables have an active taper plan.'),
            ),
          );
        }
        return;
      }
      eligibleTrackables = withPlans;
    } else {
      eligibleTrackables = trackables;
    }

    if (!mounted) return;

    final selected = await showDialog<Trackable>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Trackable for ${type.displayName}'),
        children: eligibleTrackables.map((t) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, t),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Color(t.color),
                    shape: BoxShape.circle,
                  ),
                ),
                Text(t.name),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (selected == null || !mounted) return;

    await db.insertDashboardWidget(
      type.toDbString(),
      trackableId: selected.id,
    );
  }
}
