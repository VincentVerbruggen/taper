import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/data/decay_model.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/trackables/widgets/color_palette_selector.dart';

/// EditTrackableScreen = the form for editing an existing trackable.
///
/// Like a Laravel edit form (trackables/{id}/edit.blade.php) that receives
/// the existing model via route-model binding:
///   public function edit(Trackable $trackable) { ... }
///
/// Contains ALL trackable settings in one place:
///   - Name, Unit (text fields)
///   - Decay model dropdown (None / Exponential / Linear)
///   - Half-life (shown only for exponential)
///   - Elimination rate (shown only for linear)
///   - Visibility toggle (show/hide in log form)
///   - Delete button with confirmation
class EditTrackableScreen extends ConsumerStatefulWidget {
  /// The trackable to edit — passed in like route-model binding.
  final Trackable trackable;

  const EditTrackableScreen({super.key, required this.trackable});

  @override
  ConsumerState<EditTrackableScreen> createState() =>
      _EditTrackableScreenState();
}

class _EditTrackableScreenState extends ConsumerState<EditTrackableScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _halfLifeController;
  late final TextEditingController _eliminationRateController;

  /// The currently selected decay model in the dropdown.
  /// Drives which parameter field (half-life vs elimination rate) is shown.
  late DecayModel _selectedDecayModel;

  /// Selected color from the palette (ARGB int).
  /// Initialized from the trackable's current color.
  late int _selectedColor;

  /// Whether this trackable appears in the log form dropdown.
  late bool _isVisible;

  @override
  void initState() {
    super.initState();
    // Pre-fill all form fields from the existing trackable.
    // Like old() in Laravel Blade — populates inputs with previous values.
    _nameController = TextEditingController(text: widget.trackable.name);
    _unitController = TextEditingController(text: widget.trackable.unit);
    _halfLifeController = TextEditingController(
      text: widget.trackable.halfLifeHours?.toString() ?? '',
    );
    _eliminationRateController = TextEditingController(
      text: widget.trackable.eliminationRate?.toString() ?? '',
    );
    _selectedDecayModel = DecayModel.fromString(widget.trackable.decayModel);
    _selectedColor = widget.trackable.color;
    _isVisible = widget.trackable.isVisible;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _halfLifeController.dispose();
    _eliminationRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar gives us the back button for free.
      appBar: AppBar(
        title: const Text('Edit Trackable'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Trackable name ---
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Trackable name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),

            const SizedBox(height: 16),

            // --- Unit ---
            TextField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: 'Unit',
                hintText: 'mg',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // --- Color picker ---
            // Shows the 10 palette colors as tappable circles.
            // Like a color swatch picker in a design tool.
            Text(
              'Color',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ColorPaletteSelector(
              selectedColor: _selectedColor,
              onColorSelected: (color) => setState(() => _selectedColor = color),
            ),

            const SizedBox(height: 24),

            // --- Presets section ---
            // Named dose shortcuts for this trackable (e.g., "Espresso" = 90 mg).
            // Users can add/delete presets here; they appear as chips in the
            // quick-add dialog and Add Dose screen for one-tap dose entry.
            // Like a "has-many" relationship section in a Laravel edit form.
            _buildPresetsSection(),

            const SizedBox(height: 16),

            // --- Decay model dropdown ---
            // Like a <select> in HTML. DropdownButtonFormField integrates with
            // Material 3's InputDecoration for consistent styling.
            DropdownButtonFormField<DecayModel>(
              initialValue: _selectedDecayModel,
              decoration: const InputDecoration(
                labelText: 'Decay model',
                border: OutlineInputBorder(),
              ),
              items: DecayModel.values.map((model) {
                return DropdownMenuItem<DecayModel>(
                  value: model,
                  child: Text(model.displayName),
                );
              }).toList(),
              onChanged: (model) {
                if (model != null) {
                  setState(() => _selectedDecayModel = model);
                }
              },
            ),

            const SizedBox(height: 16),

            // --- Half-life field (only for exponential) ---
            // AnimatedSize smoothly collapses/expands when the decay model changes.
            // Like a v-show transition in Vue.
            if (_selectedDecayModel == DecayModel.exponential)
              TextField(
                controller: _halfLifeController,
                decoration: const InputDecoration(
                  labelText: 'Half-life (hours)',
                  hintText: 'e.g. 5.0',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),

            // --- Elimination rate field (only for linear) ---
            if (_selectedDecayModel == DecayModel.linear)
              TextField(
                controller: _eliminationRateController,
                decoration: InputDecoration(
                  labelText: 'Elimination rate (${_unitController.text.trim().isEmpty ? 'units' : _unitController.text.trim()}/hour)',
                  hintText: 'e.g. 9.0',
                  border: const OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),

            // Spacing only needed if a parameter field was shown above.
            if (_selectedDecayModel != DecayModel.none)
              const SizedBox(height: 16),

            // --- Visibility toggle ---
            // SwitchListTile = a list tile with an integrated switch on the right.
            // Like a toggle component in a settings screen.
            SwitchListTile(
              title: const Text('Visible in log form'),
              subtitle: const Text('Hidden trackables keep their data but don\'t appear in the dropdown'),
              value: _isVisible,
              onChanged: (value) => setState(() => _isVisible = value),
              // Gives the tile a card-like outline to match other form fields.
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- Save button ---
            // Disabled until name has content (same pattern as EditDoseScreen).
            ListenableBuilder(
              listenable: _nameController,
              builder: (context, child) {
                return FilledButton.icon(
                  onPressed:
                      _nameController.text.trim().isNotEmpty ? _save : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Save Changes'),
                );
              },
            ),

            const SizedBox(height: 12),

            // --- Delete button ---
            // Error-colored outline button at the bottom. Opens a confirmation
            // dialog before actually deleting. Like a "danger zone" section.
            OutlinedButton.icon(
              onPressed: _confirmDelete,
              icon: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              label: Text(
                'Delete Trackable',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the presets management section: header, list, and "Add Preset" button.
  ///
  /// Watches presetsProvider reactively — adding/deleting a preset in the DB
  /// immediately updates this list without any manual setState() calls.
  /// Like a Livewire component that auto-refreshes when its query changes.
  Widget _buildPresetsSection() {
    final presetsAsync = ref.watch(presetsProvider(widget.trackable.id));
    final unit = _unitController.text.trim().isEmpty
        ? 'mg'
        : _unitController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Presets',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),

        // Show the list of existing presets (or nothing if loading/empty).
        presetsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, s) => Text('Error loading presets: $e'),
          data: (presetsList) {
            if (presetsList.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No presets yet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            // Each preset = a ListTile with name, amount, and delete button.
            // Like a simple CRUD list inside a parent form.
            return Column(
              children: presetsList.map((preset) {
                return ListTile(
                  // "Espresso — 90 mg"
                  title: Text(preset.name),
                  subtitle: Text('${preset.amount.toStringAsFixed(0)} $unit'),
                  // Trailing delete button — removes the preset immediately.
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
                  // Dense makes the tile shorter to keep the section compact.
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                );
              }).toList(),
            );
          },
        ),

        // "Add Preset" button — opens a dialog with name + amount fields.
        TextButton.icon(
          onPressed: _showAddPresetDialog,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Preset'),
        ),
      ],
    );
  }

  /// Shows a dialog to add a new preset (name + amount).
  /// Like a nested create form that inserts into a related table.
  void _showAddPresetDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Preset'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Espresso',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  suffixText: _unitController.text.trim().isEmpty
                      ? 'mg'
                      : _unitController.text.trim(),
                  border: const OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
                final amount = double.tryParse(amountController.text.trim());
                // Validate: non-empty name and positive number.
                if (name.isNotEmpty && amount != null && amount > 0) {
                  ref.read(databaseProvider).insertPreset(
                    widget.trackable.id,
                    name,
                    amount,
                  );
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  bool _saving = false;

  /// Update the trackable in the database and pop back to the list.
  /// Clears irrelevant fields when switching decay models:
  ///   - Switching to linear → clears halfLifeHours
  ///   - Switching to exponential → clears eliminationRate
  ///   - Switching to none → clears both
  void _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    _saving = true;

    final unit = _unitController.text.trim().isEmpty
        ? 'mg'
        : _unitController.text.trim();

    // Parse the parameter field for the selected decay model.
    // Irrelevant fields are explicitly set to null so old values don't linger.
    final halfLife = _selectedDecayModel == DecayModel.exponential
        ? double.tryParse(_halfLifeController.text.trim())
        : null;
    final eliminationRate = _selectedDecayModel == DecayModel.linear
        ? double.tryParse(_eliminationRateController.text.trim())
        : null;

    await ref.read(databaseProvider).updateTrackable(
      widget.trackable.id,
      name: name,
      unit: unit,
      decayModel: _selectedDecayModel.toDbString(),
      halfLifeHours: Value(halfLife),
      eliminationRate: Value(eliminationRate),
      isVisible: Value(_isVisible),
      color: Value(_selectedColor),
    );

    _saving = false;
    if (mounted) {
      Navigator.pop(context);
    }
  }

  /// Show a confirmation dialog before deleting.
  /// AlertDialog with "Cancel" and "Delete" actions — the "Delete" button
  /// uses error color to signal destructive intent. Like a modal confirm
  /// in JavaScript: if (confirm('Delete?')) { ... }
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Trackable'),
          content: Text(
            'Delete "${widget.trackable.name}" and all its dose history? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog.
                _delete();
              },
              child: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Delete the trackable and pop back to the list.
  void _delete() async {
    await ref.read(databaseProvider).deleteTrackable(widget.trackable.id);
    if (mounted) {
      Navigator.pop(context); // Pop the edit screen.
    }
  }
}
