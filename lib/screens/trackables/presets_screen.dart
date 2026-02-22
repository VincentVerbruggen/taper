import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/utils/validation.dart';

/// Dedicated screen for managing presets for a trackable.
///
/// Extracted from EditTrackableScreen to keep it focused on core trackable
/// fields. This follows the "navigation tile → sub-screen" pattern used
/// in iOS Settings — each section gets its own full screen.
///
/// Like a Laravel resource controller for presets:
///   Route::resource('trackables/{trackable}/presets', PresetController::class)
class PresetsScreen extends ConsumerWidget {
  /// The trackable whose presets we're managing.
  final Trackable trackable;

  const PresetsScreen({super.key, required this.trackable});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch presets reactively — list updates instantly on add/edit/delete.
    final presetsAsync = ref.watch(presetsProvider(trackable.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presets'),
      ),
      // FAB to add a new preset — opens a dialog with name + amount fields.
      floatingActionButton: FloatingActionButton(
        heroTag: 'presetsFab',
        onPressed: () => _showAddPresetDialog(
          context,
          ref,
          presetsAsync.value?.map((p) => p.name).toList() ?? [],
        ),
        child: const Icon(Icons.add),
      ),
      body: presetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error loading presets: $e')),
        data: (presetsList) {
          if (presetsList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No presets yet.\nTap + to add one.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: presetsList.length,
            itemBuilder: (context, index) {
              final preset = presetsList[index];
              // For edit dialog: exclude this preset's name so renaming to
              // the same name doesn't trigger a duplicate error.
              final otherNames = presetsList
                  .where((p) => p.id != preset.id)
                  .map((p) => p.name)
                  .toList();
              final shape = RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Card(
                  shape: shape,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    customBorder: shape,
                    onTap: () => _showEditPresetDialog(
                      context,
                      ref,
                      preset,
                      otherNames,
                    ),
                    child: ListTile(
                      title: Text(preset.name),
                      subtitle: Text(
                        '${preset.amount.toStringAsFixed(0)} ${trackable.unit}',
                      ),
                      // Delete button — removes the preset immediately.
                      // Presets are lightweight; no confirmation dialog needed.
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () {
                          ref.read(databaseProvider).deletePreset(preset.id);
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Shows a dialog to add a new preset (name + amount).
  /// Like a nested create form that inserts into a related table.
  /// [existingNames] = names of other presets in this trackable, for duplicate checking.
  void _showAddPresetDialog(
    BuildContext context,
    WidgetRef ref,
    List<String> existingNames,
  ) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    // Tracks whether the user has attempted to save.
    // Before this, empty fields don't show "Required" (avoids error spam on open).
    // After tapping Add, empty required fields light up with errors.
    // Like Laravel's $errors bag — only populated after form submission.
    var submitted = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        // StatefulBuilder so the dialog can rebuild when text changes —
        // needed for live errorText updates on the amount and name fields.
        // Like using Alpine.js x-data inside a Blade modal.
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Compute error text: "Required" takes priority over other validators.
            final nameError = submitted && nameController.text.trim().isEmpty
                ? 'Required'
                : duplicateNameError(nameController.text, existingNames);
            final amountError = submitted && amountController.text.trim().isEmpty
                ? 'Required'
                : numericFieldError(amountController.text);

            return AlertDialog(
              title: const Text('Add Preset'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Espresso',
                      border: const OutlineInputBorder(),
                      errorText: nameError,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      suffixText: trackable.unit,
                      border: const OutlineInputBorder(),
                      errorText: amountError,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final amount =
                        double.tryParse(amountController.text.trim());
                    // If validation fails, mark as submitted so error messages
                    // appear, then rebuild the dialog to show them.
                    if (name.isEmpty ||
                        duplicateNameError(name, existingNames) != null ||
                        amount == null ||
                        amount <= 0) {
                      submitted = true;
                      setDialogState(() {});
                      return;
                    }
                    ref.read(databaseProvider).insertPreset(
                      trackable.id,
                      name,
                      amount,
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Shows a dialog to edit an existing preset's name and/or amount.
  /// Pre-fills with the current values — like editing a row in a related table.
  void _showEditPresetDialog(
    BuildContext context,
    WidgetRef ref,
    Preset preset,
    List<String> existingNames,
  ) {
    final nameController = TextEditingController(text: preset.name);
    final amountController = TextEditingController(
      text: preset.amount.toStringAsFixed(
        preset.amount == preset.amount.roundToDouble() ? 0 : 1,
      ),
    );
    var submitted = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final nameError = submitted && nameController.text.trim().isEmpty
                ? 'Required'
                : duplicateNameError(nameController.text, existingNames);
            final amountError = submitted && amountController.text.trim().isEmpty
                ? 'Required'
                : numericFieldError(amountController.text);

            return AlertDialog(
              title: const Text('Edit Preset'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: const OutlineInputBorder(),
                      errorText: nameError,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      suffixText: trackable.unit,
                      border: const OutlineInputBorder(),
                      errorText: amountError,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final amount =
                        double.tryParse(amountController.text.trim());
                    if (name.isEmpty ||
                        duplicateNameError(name, existingNames) != null ||
                        amount == null ||
                        amount <= 0) {
                      submitted = true;
                      setDialogState(() {});
                      return;
                    }
                    ref.read(databaseProvider).updatePreset(
                      preset.id,
                      name: name,
                      amount: amount,
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
