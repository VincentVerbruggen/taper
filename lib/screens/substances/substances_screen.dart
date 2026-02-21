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
              onSave: (name) => _updateSubstance(substance.id, name),
              onCancel: () => setState(() => _editingSubstance = null),
            ),
          );
        }

        // Normal list item — tap to edit, trash icon to delete
        return _SubstanceListItem(
          substance: substance,
          onEdit: () {
            setState(() {
              _editingSubstance = substance;
              _showAddForm = false; // Close add form when editing
            });
          },
          onDelete: () => _deleteSubstance(substance.id),
        );
      },
    );
  }

  // --- Mutation methods ---
  // These call the database directly via ref.read(databaseProvider).
  // ref.read() = one-time access (no subscription, no rebuild).
  // Like app()->make(AppDatabase::class)->method() in Laravel.

  void _addSubstance(String name) async {
    await ref.read(databaseProvider).insertSubstance(name);
    setState(() => _showAddForm = false);
  }

  void _updateSubstance(int id, String newName) async {
    await ref.read(databaseProvider).updateSubstance(id, newName);
    setState(() => _editingSubstance = null);
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
/// Tap to edit, trash icon to delete.
class _SubstanceListItem extends StatelessWidget {
  final Substance substance;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SubstanceListItem({
    required this.substance,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ListTile = Material 3 list item with title + trailing slots.
        ListTile(
          title: Text(substance.name),
          trailing: IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: onDelete,
          ),
          onTap: onEdit,
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// Reusable form card for adding or editing a substance.
///
/// Used in two modes:
///   1. "Add Substance" — at top of list when FAB is tapped
///   2. "Edit Substance" — replaces a list item inline when tapped
///
/// Like a Blade partial (substances/_form.blade.php) used for both
/// create and edit routes.
///
/// StatefulWidget because it manages its own TextEditingController.
class _SubstanceFormCard extends StatefulWidget {
  final String title;
  final String initialName;
  final ValueChanged<String> onSave;
  final VoidCallback onCancel;

  const _SubstanceFormCard({
    required this.title,
    required this.initialName,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_SubstanceFormCard> createState() => _SubstanceFormCardState();
}

class _SubstanceFormCardState extends State<_SubstanceFormCard> {
  // TextEditingController = the wire:model backing property.
  // It holds the current text value and notifies the TextField when it changes.
  // Like: public string $name = ''; in Livewire.
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing name for edit mode, empty for add mode.
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    // Always dispose controllers to prevent memory leaks.
    // Like fclose($handle) in PHP.
    _controller.dispose();
    super.dispose();
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

            // Text input
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Substance name',
                border: OutlineInputBorder(),
              ),
              // autofocus opens the keyboard immediately.
              autofocus: true,
              // Pressing Enter on the keyboard saves.
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  widget.onSave(value.trim());
                }
              },
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
                // ListenableBuilder rebuilds only the Save button when text changes.
                // Enables/disables based on whether input is empty.
                ListenableBuilder(
                  listenable: _controller,
                  builder: (context, child) {
                    return TextButton(
                      onPressed: _controller.text.trim().isNotEmpty
                          ? () => widget.onSave(_controller.text.trim())
                          : null, // null = disabled button
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
