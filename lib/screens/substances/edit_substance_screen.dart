import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';

/// EditSubstanceScreen = the form for editing an existing substance.
///
/// Like a Laravel edit form (substances/{id}/edit.blade.php) that receives
/// the existing model via route-model binding:
///   public function edit(Substance $substance) { ... }
///
/// Mirrors the pattern of EditDoseScreen:
///   - Receives the existing Substance as a constructor parameter
///   - Pre-fills all fields from the existing data
///   - Save calls updateSubstance() instead of insertSubstance()
///   - Navigator.pop() after saving returns to the list
class EditSubstanceScreen extends ConsumerStatefulWidget {
  /// The substance to edit — passed in like route-model binding.
  final Substance substance;

  const EditSubstanceScreen({super.key, required this.substance});

  @override
  ConsumerState<EditSubstanceScreen> createState() =>
      _EditSubstanceScreenState();
}

class _EditSubstanceScreenState extends ConsumerState<EditSubstanceScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _halfLifeController;

  @override
  void initState() {
    super.initState();
    // Pre-fill all form fields from the existing substance.
    // Like old() in Laravel Blade — populates inputs with previous values.
    _nameController = TextEditingController(text: widget.substance.name);
    _unitController = TextEditingController(text: widget.substance.unit);
    _halfLifeController = TextEditingController(
      text: widget.substance.halfLifeHours?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _halfLifeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar gives us the back button for free.
      appBar: AppBar(
        title: const Text('Edit Substance'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Substance name ---
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Substance name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),

            const SizedBox(height: 16),

            // --- Unit + Half-life in a row ---
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
          ],
        ),
      ),
    );
  }

  bool _saving = false;

  /// Update the substance in the database and pop back to the list.
  void _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    _saving = true;

    final unit = _unitController.text.trim().isEmpty
        ? 'mg'
        : _unitController.text.trim();
    final halfLife = double.tryParse(_halfLifeController.text.trim());

    await ref.read(databaseProvider).updateSubstance(
      widget.substance.id,
      name: name,
      unit: unit,
      halfLifeHours: Value(halfLife),
    );

    _saving = false;
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
