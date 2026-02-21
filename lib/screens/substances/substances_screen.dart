import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/substances/edit_substance_screen.dart';

/// SubstancesScreen = the full CRUD screen for managing substances.
///
/// ConsumerStatefulWidget = a StatefulWidget that can access Riverpod providers.
/// "Consumer" means "I consume providers" (dependency injection).
/// Like a Livewire component with both local state ($showModal) AND
/// injected dependencies ($this->substanceService).
class SubstancesScreen extends ConsumerStatefulWidget {
  const SubstancesScreen({super.key});

  @override
  ConsumerState<SubstancesScreen> createState() => _SubstancesScreenState();
}

class _SubstancesScreenState extends ConsumerState<SubstancesScreen> {
  @override
  Widget build(BuildContext context) {
    final substancesAsync = ref.watch(substancesProvider);

    return Scaffold(
      // FAB opens the add substance dialog.
      floatingActionButton: FloatingActionButton(
        heroTag: 'addSubstanceFab',
        onPressed: () => _showAddSubstanceDialog(context),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: false,
        child: substancesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (substances) => _buildSubstancesList(substances),
        ),
      ),
    );
  }

  Widget _buildSubstancesList(List<Substance> substances) {
    // Empty state — show a hint when no substances.
    if (substances.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Substances',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 48),
          const Center(
            child: Text('No substances yet. Tap + to add one.'),
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
        // --- "Substances" heading ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Substances',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),

        // --- Reorderable substance list ---
        Expanded(
          child: ReorderableListView.builder(
            itemCount: substances.length,
            onReorder: (oldIndex, newIndex) =>
                _onReorder(substances, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final substance = substances[index];

              return _SubstanceListItem(
                key: ValueKey(substance.id),
                substance: substance,
                isFirst: index == 0,
                isLast: index == substances.length - 1,
                onEdit: () => _editSubstance(substance),
                onDelete: () => _deleteSubstance(substance.id),
                onToggleMain: () => _setMainSubstance(substance.id),
                onToggleVisibility: () => _toggleVisibility(
                  substance.id,
                  substance.isVisible,
                ),
                onMoveUp: () => _onReorder(substances, index, index - 1),
                onMoveDown: () => _onReorder(substances, index, index + 2),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Handle drag-to-reorder.
  void _onReorder(List<Substance> substances, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final ids = substances.map((s) => s.id).toList();
    final movedId = ids.removeAt(oldIndex);
    ids.insert(newIndex, movedId);
    ref.read(databaseProvider).reorderSubstances(ids);
  }

  // --- Mutation methods ---

  /// Navigate to the edit screen for this substance.
  /// Like clicking a row in a Laravel resource table → GET /substances/{id}/edit.
  void _editSubstance(Substance substance) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditSubstanceScreen(substance: substance),
      ),
    );
  }

  void _setMainSubstance(int id) async {
    await ref.read(databaseProvider).setMainSubstance(id);
  }

  void _toggleVisibility(int id, bool currentlyVisible) async {
    await ref.read(databaseProvider).toggleSubstanceVisibility(
      id,
      !currentlyVisible,
    );
  }

  void _deleteSubstance(int id) async {
    await ref.read(databaseProvider).deleteSubstance(id);
  }

  /// Shows a bottom sheet dialog for adding a new substance.
  /// Has the same fields as the inline form: name, unit, half-life.
  /// Like a modal create form that slides up from the bottom.
  void _showAddSubstanceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return _AddSubstanceBottomSheet(
          onSave: (name, unit, halfLife) async {
            await ref.read(databaseProvider).insertSubstance(
              name,
              unit: unit,
              halfLifeHours: halfLife,
            );
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          },
        );
      },
    );
  }
}

/// Bottom sheet form for adding a new substance.
/// Contains name, unit, and half-life fields, same as the old inline form.
class _AddSubstanceBottomSheet extends StatefulWidget {
  /// Callback that receives the form values and should close the sheet.
  final void Function(String name, String unit, double? halfLife) onSave;

  const _AddSubstanceBottomSheet({required this.onSave});

  @override
  State<_AddSubstanceBottomSheet> createState() => _AddSubstanceBottomSheetState();
}

class _AddSubstanceBottomSheetState extends State<_AddSubstanceBottomSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _halfLifeController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _unitController = TextEditingController(text: 'mg');
    _halfLifeController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _halfLifeController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final unit = _unitController.text.trim().isEmpty
        ? 'mg'
        : _unitController.text.trim();
    final halfLife = double.tryParse(_halfLifeController.text.trim());

    widget.onSave(name, unit, halfLife);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add Substance',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),

          // Substance name input.
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Substance name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),

          const SizedBox(height: 12),

          // Unit + Half-life in a row.
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _unitController,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    hintText: 'mg',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _halfLifeController,
                  decoration: const InputDecoration(
                    labelText: 'Half-life (hours)',
                    hintText: 'e.g. 5.0',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Save button — disabled until name has content.
          ListenableBuilder(
            listenable: _nameController,
            builder: (context, child) {
              return FilledButton.icon(
                onPressed: _nameController.text.trim().isNotEmpty
                    ? _submit
                    : null,
                icon: const Icon(Icons.check),
                label: const Text('Add Substance'),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets — like Blade partials (substances/_item.blade.php)
// ---------------------------------------------------------------------------

/// A single substance in the list.
/// Shows star (main), name, reorder arrows, eye (visibility), and delete icons.
/// Tap name to edit.
class _SubstanceListItem extends StatelessWidget {
  final Substance substance;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleMain;
  final VoidCallback onToggleVisibility;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _SubstanceListItem({
    super.key,
    required this.substance,
    required this.isFirst,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleMain,
    required this.onToggleVisibility,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final isHidden = !substance.isVisible;

    return Column(
      children: [
        ListTile(
          leading: IconButton(
            icon: Icon(
              substance.isMain ? Icons.star : Icons.star_outline,
              color: isHidden
                  ? Theme.of(context).colorScheme.onSurface.withAlpha(77)
                  : substance.isMain
                      ? Colors.amber
                      : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: isHidden ? null : onToggleMain,
            tooltip: 'Set as default',
          ),
          title: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Color(substance.color).withAlpha(isHidden ? 77 : 255),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  substance.name,
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
              ),
            ],
          ),
          subtitle: Text(
            substance.halfLifeHours != null
                ? '${substance.unit} \u00B7 half-life: ${substance.halfLifeHours}h'
                : substance.unit,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(
                isHidden ? 77 : 179,
              ),
            ),
          ),
          trailing: SizedBox(
            width: 192,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Up/down arrows for reordering.
                // Disabled when at top/bottom of the list.
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 20),
                  onPressed: isFirst ? null : onMoveUp,
                  tooltip: 'Move up',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 20),
                  onPressed: isLast ? null : onMoveDown,
                  tooltip: 'Move down',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(
                    isHidden ? Icons.visibility_off : Icons.visibility,
                    color: isHidden
                        ? Theme.of(context).colorScheme.onSurface.withAlpha(128)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onToggleVisibility,
                  tooltip: isHidden ? 'Show' : 'Hide',
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          onTap: onEdit,
        ),
        const Divider(height: 1),
      ],
    );
  }
}

