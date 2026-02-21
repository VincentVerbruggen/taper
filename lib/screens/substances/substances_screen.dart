import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';

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
  // Whether the "add new substance" form is visible.
  // Like: public bool $showAddForm = false; in Livewire.
  bool _showAddForm = false;

  // Which substance is being edited (null = not editing).
  // Like: public ?Substance $editing = null; in Livewire.
  Substance? _editingSubstance;

  @override
  Widget build(BuildContext context) {
    // ref.watch() = subscribe to a provider and rebuild when it changes.
    // substancesProvider is a StreamProvider, so it returns AsyncValue
    // wrapping three states: loading, data, or error.
    final substancesAsync = ref.watch(substancesProvider);

    return Scaffold(
      // FAB = Floating Action Button, the "+" at bottom right.
      // Hidden when the add form is already showing.
      floatingActionButton: _showAddForm
          ? null
          : FloatingActionButton(
              onPressed: () {
                setState(() {
                  _showAddForm = true;
                  _editingSubstance = null; // Close any open edit form
                });
              },
              child: const Icon(Icons.add),
            ),

      // AsyncValue.when() = pattern matching on the stream state.
      // Like a Blade @if($loading) / @elseif($error) / @else pattern.
      body: substancesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (substances) => _buildSubstancesList(substances),
      ),
    );
  }

  Widget _buildSubstancesList(List<Substance> substances) {
    // Empty state — show a hint when no substances and no add form.
    if (substances.isEmpty && !_showAddForm) {
      return const Center(
        child: Text('No substances yet. Tap + to add one.'),
      );
    }

    // ListView.builder lazily builds items as they scroll into view.
    // If the add form is visible, it takes index 0 and the rest shift by 1.
    final formOffset = _showAddForm ? 1 : 0;

    return ListView.builder(
      itemCount: substances.length + formOffset,
      itemBuilder: (context, index) {
        // Add form at the top of the list
        if (_showAddForm && index == 0) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: _SubstanceFormCard(
              title: 'Add Substance',
              initialName: '',
              initialUnit: 'mg',
              initialHalfLife: null,
              onSave: _addSubstance,
              onCancel: () => setState(() => _showAddForm = false),
            ),
          );
        }

        final substance = substances[index - formOffset];

        // Inline edit form replaces the list item when tapped
        if (_editingSubstance?.id == substance.id) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
            child: _SubstanceFormCard(
              title: 'Edit Substance',
              initialName: substance.name,
              initialUnit: substance.unit,
              initialHalfLife: substance.halfLifeHours,
              onSave: (name, unit, halfLife) =>
                  _updateSubstance(substance.id, name, unit, halfLife),
              onCancel: () => setState(() => _editingSubstance = null),
            ),
          );
        }

        // Normal list item — tap to edit, icons to toggle main/visibility/delete
        return _SubstanceListItem(
          substance: substance,
          onEdit: () {
            setState(() {
              _editingSubstance = substance;
              _showAddForm = false; // Close add form when editing
            });
          },
          onDelete: () => _deleteSubstance(substance.id),
          onToggleMain: () => _setMainSubstance(substance.id),
          onToggleVisibility: () => _toggleVisibility(
            substance.id,
            substance.isVisible,
          ),
        );
      },
    );
  }

  // --- Mutation methods ---
  // These call the database directly via ref.read(databaseProvider).
  // ref.read() = one-time access (no subscription, no rebuild).
  // Like app()->make(AppDatabase::class)->method() in Laravel.

  void _addSubstance(String name, String unit, double? halfLifeHours) async {
    await ref.read(databaseProvider).insertSubstance(
      name,
      unit: unit,
      halfLifeHours: halfLifeHours,
    );
    setState(() => _showAddForm = false);
  }

  void _updateSubstance(int id, String name, String unit, double? halfLifeHours) async {
    await ref.read(databaseProvider).updateSubstance(
      id,
      name: name,
      unit: unit,
      // Value(halfLifeHours) — explicitly set, even if null (to clear it).
      halfLifeHours: Value(halfLifeHours),
    );
    setState(() => _editingSubstance = null);
  }

  /// Set a substance as the main (default in Log form dropdown).
  /// Like clicking a radio button — only one can be active at a time.
  void _setMainSubstance(int id) async {
    await ref.read(databaseProvider).setMainSubstance(id);
  }

  /// Toggle a substance's visibility in the Log form dropdown.
  /// Hidden substances keep their dose history — like soft-deleting.
  void _toggleVisibility(int id, bool currentlyVisible) async {
    await ref.read(databaseProvider).toggleSubstanceVisibility(
      id,
      !currentlyVisible,
    );
  }

  /// Delete immediately, no confirmation dialog.
  void _deleteSubstance(int id) async {
    if (_editingSubstance?.id == id) {
      setState(() => _editingSubstance = null);
    }
    await ref.read(databaseProvider).deleteSubstance(id);
  }
}

// ---------------------------------------------------------------------------
// Private widgets — like Blade partials (substances/_item.blade.php)
// ---------------------------------------------------------------------------

/// A single substance in the list.
/// Shows star (main), name, eye (visibility), and delete icons.
/// Tap name to edit.
///
/// Layout:
///   [★ star] [Substance Name] [👁 eye] [🗑 delete]
///   leading    title            trailing (Row of two icons)
class _SubstanceListItem extends StatelessWidget {
  final Substance substance;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleMain;
  final VoidCallback onToggleVisibility;

  const _SubstanceListItem({
    required this.substance,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleMain,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final isHidden = !substance.isVisible;

    return Column(
      children: [
        ListTile(
          // Leading: Star icon for "main" substance (the default in the Log form).
          // Filled star = this is the main substance; outlined = not main.
          // Disabled (greyed out) when hidden — can't set a hidden substance as main.
          // Like a radio button with a star visual instead of a circle.
          leading: IconButton(
            icon: Icon(
              substance.isMain ? Icons.star : Icons.star_outline,
              // Gold when main, grey when not, dimmed when hidden.
              color: isHidden
                  ? Theme.of(context).colorScheme.onSurface.withAlpha(77)
                  : substance.isMain
                      ? Colors.amber
                      : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            // null = disabled. Can't make a hidden substance the default.
            onPressed: isHidden ? null : onToggleMain,
            tooltip: 'Set as default',
          ),

          // Title row: color dot + substance name.
          // The color dot shows the auto-assigned chart color.
          // Strikethrough + dimmed when hidden to show it won't appear
          // in the Log form dropdown.
          title: Row(
            children: [
              // Small circle showing the substance's chart color.
              // Like a colored bullet point in a legend.
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

          // Subtitle: unit + half-life info (e.g., "mg · half-life: 5.0h").
          // Shows just the unit if there's no half-life (e.g., Water → "ml").
          subtitle: Text(
            substance.halfLifeHours != null
                ? '${substance.unit} · half-life: ${substance.halfLifeHours}h'
                : substance.unit,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(
                isHidden ? 77 : 179,
              ),
            ),
          ),

          // Trailing: eye toggle + delete button in a Row.
          // Row must be wrapped in a SizedBox with a fixed width — otherwise
          // ListTile's trailing slot expands to fill all available space.
          // Like putting two inline buttons in a <td> cell.
          trailing: SizedBox(
            width: 96,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Eye icon: open = visible, closed = hidden.
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
                // Delete icon — same as before.
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

/// Callback type for the substance form — passes name, unit, and optional halfLifeHours.
/// Like a form DTO: SubstanceFormData { name, unit, halfLifeHours }.
typedef SubstanceFormCallback = void Function(String name, String unit, double? halfLifeHours);

/// Reusable form card for adding or editing a substance.
///
/// Used in two modes:
///   1. "Add Substance" — at top of list when FAB is tapped
///   2. "Edit Substance" — replaces a list item inline when tapped
///
/// Like a Blade partial (substances/_form.blade.php) used for both
/// create and edit routes.
///
/// StatefulWidget because it manages its own TextEditingControllers.
class _SubstanceFormCard extends StatefulWidget {
  final String title;
  final String initialName;
  final String initialUnit;
  final double? initialHalfLife;
  final SubstanceFormCallback onSave;
  final VoidCallback onCancel;

  const _SubstanceFormCard({
    required this.title,
    required this.initialName,
    required this.initialUnit,
    required this.initialHalfLife,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_SubstanceFormCard> createState() => _SubstanceFormCardState();
}

class _SubstanceFormCardState extends State<_SubstanceFormCard> {
  // One controller per text field — like separate wire:model properties in Livewire.
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _halfLifeController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _unitController = TextEditingController(text: widget.initialUnit);
    // Show half-life as a number string, empty if null (no decay tracking).
    _halfLifeController = TextEditingController(
      text: widget.initialHalfLife?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _halfLifeController.dispose();
    super.dispose();
  }

  /// Submit the form if name is valid.
  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final unit = _unitController.text.trim().isEmpty
        ? 'mg'
        : _unitController.text.trim();
    // Empty half-life field = null (no decay tracking).
    final halfLife = double.tryParse(_halfLifeController.text.trim());

    widget.onSave(name, unit, halfLife);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: title + close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onCancel,
                ),
              ],
            ),

            // Substance name input
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Substance name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),

            const SizedBox(height: 12),

            // Unit + Half-life in a row — like two <input> fields side by side.
            // Expanded gives each field equal space within the Row.
            Row(
              children: [
                // Unit field — free text input, defaults to "mg".
                // Like <input type="text" value="mg" placeholder="Unit">.
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
                // Half-life field — numeric input, optional.
                // Empty = null = no decay tracking for this substance.
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

            const SizedBox(height: 8),

            // Action buttons: Cancel + Save
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
                // ListenableBuilder rebuilds only the Save button when name changes.
                // Save is disabled until name has content.
                ListenableBuilder(
                  listenable: _nameController,
                  builder: (context, child) {
                    return TextButton(
                      onPressed: _nameController.text.trim().isNotEmpty
                          ? _submit
                          : null,
                      child: const Text('Save'),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
