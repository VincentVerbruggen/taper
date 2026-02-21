import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/decay_model.dart';
import 'package:taper/providers/database_providers.dart';

/// AddTrackableScreen = the form for creating a new trackable.
///
/// Like a Laravel create form (trackables/create.blade.php).
/// Mirrors EditTrackableScreen's layout but with empty defaults:
///   - Name, Unit (text fields)
///   - Decay model dropdown (defaults to None)
///   - Half-life (shown only for exponential)
///   - Elimination rate (shown only for linear)
///
/// No visibility toggle or delete button — those only make sense for
/// existing trackables and are available in the edit screen.
class AddTrackableScreen extends ConsumerStatefulWidget {
  const AddTrackableScreen({super.key});

  @override
  ConsumerState<AddTrackableScreen> createState() =>
      _AddTrackableScreenState();
}

class _AddTrackableScreenState extends ConsumerState<AddTrackableScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _halfLifeController;
  late final TextEditingController _eliminationRateController;

  /// The currently selected decay model in the dropdown.
  /// Drives which parameter field (half-life vs elimination rate) is shown.
  /// Defaults to "None" for new trackables.
  DecayModel _selectedDecayModel = DecayModel.none;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _unitController = TextEditingController(text: 'mg');
    _halfLifeController = TextEditingController();
    _eliminationRateController = TextEditingController();
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
      appBar: AppBar(
        title: const Text('Add Trackable'),
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

            // --- Decay model dropdown ---
            // Same as edit screen. Defaults to "None" for new trackables.
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

            // --- Save button ---
            // Disabled until name has content.
            ListenableBuilder(
              listenable: _nameController,
              builder: (context, child) {
                return FilledButton.icon(
                  onPressed:
                      _nameController.text.trim().isNotEmpty ? _save : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Add Trackable'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _saving = false;

  /// Insert the trackable into the database and pop back to the list.
  void _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    _saving = true;

    final unit = _unitController.text.trim().isEmpty
        ? 'mg'
        : _unitController.text.trim();

    // Parse the parameter field for the selected decay model.
    // Only the relevant field is parsed; the other stays null.
    final halfLife = _selectedDecayModel == DecayModel.exponential
        ? double.tryParse(_halfLifeController.text.trim())
        : null;
    final eliminationRate = _selectedDecayModel == DecayModel.linear
        ? double.tryParse(_eliminationRateController.text.trim())
        : null;

    await ref.read(databaseProvider).insertTrackable(
      name,
      unit: unit,
      decayModel: _selectedDecayModel.toDbString(),
      halfLifeHours: halfLife,
      eliminationRate: eliminationRate,
    );

    _saving = false;
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
