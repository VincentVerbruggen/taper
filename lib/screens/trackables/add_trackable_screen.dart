import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/decay_model.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/utils/validation.dart';

/// AddTrackableScreen = the form for creating a new trackable.
///
/// Like a Laravel create form (trackables/create.blade.php).
/// Unified header pattern: Back arrow | Title | Checkmark (Save).
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
  late final TextEditingController _absorptionMinutesController;

  /// The currently selected decay model in the dropdown.
  DecayModel _selectedDecayModel = DecayModel.none;

  /// Tracks whether the user has attempted to save.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _unitController = TextEditingController(text: 'mg');
    _halfLifeController = TextEditingController();
    _eliminationRateController = TextEditingController();
    _absorptionMinutesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _halfLifeController.dispose();
    _eliminationRateController.dispose();
    _absorptionMinutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch all trackables to check for duplicate names.
    final existingTrackableNames = ref.watch(trackablesProvider)
        .value
        ?.map((t) => t.name)
        .toList() ?? [];

    return Scaffold(
      // Unified AppBar pattern: Title + Checkmark action.
      appBar: AppBar(
        title: const Text('Add Trackable'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Add Trackable',
            onPressed: () => _save(existingTrackableNames),
          ),
        ],
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
              decoration: InputDecoration(
                labelText: 'Trackable name',
                border: const OutlineInputBorder(),
                errorText: _submitted && _nameController.text.trim().isEmpty
                    ? 'Required'
                    : duplicateNameError(_nameController.text, existingTrackableNames),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(existingTrackableNames),
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
                decoration: InputDecoration(
                  labelText: 'Half-life (hours)',
                  hintText: 'e.g. 5.0',
                  border: const OutlineInputBorder(),
                  errorText: numericFieldError(_halfLifeController.text),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                onChanged: (_) => setState(() {}),
              ),

            // --- Elimination rate field (only for linear) ---
            if (_selectedDecayModel == DecayModel.linear)
              TextField(
                controller: _eliminationRateController,
                decoration: InputDecoration(
                  labelText: 'Elimination rate (${_unitController.text.trim().isEmpty ? 'units' : _unitController.text.trim()}/hour)',
                  hintText: 'e.g. 9.0',
                  border: const OutlineInputBorder(),
                  errorText: numericFieldError(_eliminationRateController.text),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                onChanged: (_) => setState(() {}),
              ),

            // --- Absorption time field ---
            if (_selectedDecayModel != DecayModel.none) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _absorptionMinutesController,
                decoration: InputDecoration(
                  labelText: 'Absorption time (minutes)',
                  hintText: 'e.g. 30 (optional)',
                  border: const OutlineInputBorder(),
                  errorText: numericFieldError(_absorptionMinutesController.text),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ],

            if (_selectedDecayModel != DecayModel.none)
              const SizedBox(height: 16),

            // Note: Save button moved to AppBar actions for UI consistency.
          ],
        ),
      ),
    );
  }

  bool _saving = false;

  /// Insert the trackable into the database and pop back to the list.
  void _save(List<String> existingNames) async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty || duplicateNameError(name, existingNames) != null) {
      _submitted = true;
      setState(() {});
      return;
    }
    _saving = true;

    final unit = _unitController.text.trim().isEmpty
        ? 'mg'
        : _unitController.text.trim();

    final halfLife = _selectedDecayModel == DecayModel.exponential
        ? double.tryParse(_halfLifeController.text.trim())
        : null;
    final eliminationRate = _selectedDecayModel == DecayModel.linear
        ? double.tryParse(_eliminationRateController.text.trim())
        : null;

    final absorptionMinutes = _selectedDecayModel != DecayModel.none
        ? double.tryParse(_absorptionMinutesController.text.trim())
        : null;

    await ref.read(databaseProvider).insertTrackable(
      name,
      unit: unit,
      decayModel: _selectedDecayModel.toDbString(),
      halfLifeHours: halfLife,
      eliminationRate: eliminationRate,
      absorptionMinutes: absorptionMinutes,
    );

    _saving = false;
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
