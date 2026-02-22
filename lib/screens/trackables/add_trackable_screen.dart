import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/decay_model.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/utils/validation.dart';

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
  late final TextEditingController _absorptionMinutesController;

  /// The currently selected decay model in the dropdown.
  /// Drives which parameter field (half-life vs elimination rate) is shown.
  /// Defaults to "None" for new trackables.
  DecayModel _selectedDecayModel = DecayModel.none;

  /// Tracks whether the user has attempted to save.
  /// Before this, empty required fields don't show "Required" (avoids error
  /// spam when the form first opens). After tapping save, they light up.
  /// Like Laravel's $errors bag — only populated after form submission.
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
    // Like: $existingNames = Trackable::pluck('name')->toArray();
    final existingTrackableNames = ref.watch(trackablesProvider)
        .value
        ?.map((t) => t.name)
        .toList() ?? [];

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
              decoration: InputDecoration(
                labelText: 'Trackable name',
                border: const OutlineInputBorder(),
                // "Required" only shows after the user tries to save (avoids
                // red text the moment the form opens). Duplicate check is live.
                errorText: _submitted && _nameController.text.trim().isEmpty
                    ? 'Required'
                    : duplicateNameError(_nameController.text, existingTrackableNames),
              ),
              // Trigger rebuild so the duplicate check updates as the user types.
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
                decoration: InputDecoration(
                  labelText: 'Half-life (hours)',
                  hintText: 'e.g. 5.0',
                  border: const OutlineInputBorder(),
                  // Show inline error when input is non-empty but not a valid number.
                  // Like Laravel's @error('half_life') directive in Blade.
                  errorText: numericFieldError(_halfLifeController.text),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                // Only allow digits and decimal point — prevents typing letters.
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                // Trigger rebuild so errorText updates as the user types.
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

            // --- Absorption time field (for exponential and linear) ---
            // How long it takes for the dose to be fully absorbed before decay
            // begins. Creates a linear ramp-up phase on the curve.
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

            // Spacing only needed if a parameter field was shown above.
            if (_selectedDecayModel != DecayModel.none)
              const SizedBox(height: 16),

            // --- Save button ---
            // Always enabled — tapping it with invalid fields triggers
            // error messages instead of silently staying disabled.
            FilledButton.icon(
              onPressed: () => _save(existingTrackableNames),
              icon: const Icon(Icons.check),
              label: const Text('Add Trackable'),
            ),
          ],
        ),
      ),
    );
  }

  bool _saving = false;

  /// Insert the trackable into the database and pop back to the list.
  /// If validation fails, sets _submitted = true so error messages appear.
  void _save(List<String> existingNames) async {
    if (_saving) return;
    final name = _nameController.text.trim();
    // Validate — if anything is wrong, mark as submitted so errors show,
    // then rebuild. The user sees exactly which fields need fixing.
    if (name.isEmpty || duplicateNameError(name, existingNames) != null) {
      _submitted = true;
      setState(() {});
      return;
    }
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

    // Absorption time is relevant for both exponential and linear models.
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
