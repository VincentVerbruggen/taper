import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/log/widgets/time_picker.dart';

/// EditDoseScreen = the form for editing an existing dose log.
///
/// Like a Laravel edit form (doses/{id}/edit.blade.php) that receives
/// the existing model via route-model binding:
///   public function edit(DoseLog $doseLog) { return view('doses.edit', compact('doseLog')); }
///
/// Structurally identical to the create form in LogDoseScreen, but:
///   - Receives the existing entry as a constructor parameter
///   - Pre-fills all fields from the existing data
///   - Save calls updateDoseLog() instead of insertDoseLog()
///   - Navigator.pop() after saving returns to the log list
class EditDoseScreen extends ConsumerStatefulWidget {
  /// The dose log entry to edit — includes both the DoseLog and its Substance.
  /// Like passing $doseLog->load('substance') to the view.
  final DoseLogWithSubstance entry;

  const EditDoseScreen({super.key, required this.entry});

  @override
  ConsumerState<EditDoseScreen> createState() => _EditDoseScreenState();
}

class _EditDoseScreenState extends ConsumerState<EditDoseScreen> {
  // Currently selected substance — pre-filled from the existing entry.
  Substance? _selectedSubstance;

  // Controller for the amount text field — pre-filled with existing amount.
  final _amountController = TextEditingController();

  // Date and time — pre-filled from the existing loggedAt timestamp.
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();

    // Pre-fill all form fields from the existing entry.
    // Like old() in Laravel Blade — populates inputs with previous values.
    _selectedSubstance = widget.entry.substance;
    _amountController.text = widget.entry.doseLog.amount.toStringAsFixed(0);

    final loggedAt = widget.entry.doseLog.loggedAt;
    _selectedDate = loggedAt;
    _selectedTime = TimeOfDay.fromDateTime(loggedAt);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the substances list so the dropdown stays in sync if substances
    // change while the edit screen is open (unlikely but defensive).
    final substancesAsync = ref.watch(substancesProvider);

    return Scaffold(
      // AppBar gives us the back button for free — like having a <a href="{{ url()->previous() }}">
      // back link in a Blade layout. Flutter's Navigator handles it automatically.
      appBar: AppBar(
        title: const Text('Edit Dose'),
      ),
      body: substancesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (substances) => _buildForm(substances),
      ),
    );
  }

  Widget _buildForm(List<Substance> substances) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Substance picker ---
          // Same dropdown as the create form, but with initialValue set
          // to the existing substance. Like <select> with selected="...".
          DropdownButtonFormField<Substance>(
            // Pre-select the substance that matches the existing entry's substance ID.
            // We find by ID (not reference) because the Substance objects from the
            // provider stream are different instances than widget.entry.substance.
            // Like: <option> with @selected($s->id === $doseLog->substance_id)
            initialValue: substances.where((s) => s.id == _selectedSubstance?.id).firstOrNull,
            decoration: const InputDecoration(
              labelText: 'Substance',
              border: OutlineInputBorder(),
            ),
            items: substances.map((s) {
              return DropdownMenuItem<Substance>(
                value: s,
                child: Text(s.name),
              );
            }).toList(),
            onChanged: (substance) {
              setState(() => _selectedSubstance = substance);
            },
          ),

          const SizedBox(height: 16),

          // --- Amount input ---
          // Pre-filled with the existing amount.
          // suffixText shows the substance's unit dynamically.
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Amount',
              suffixText: _selectedSubstance?.unit ?? 'mg',
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
          ),

          const SizedBox(height: 16),

          // --- Time picker ---
          // Pre-filled with the existing date/time.
          TimePicker(
            date: _selectedDate,
            time: _selectedTime,
            onDateChanged: (date) => setState(() => _selectedDate = date),
            onTimeChanged: (time) => setState(() => _selectedTime = time),
          ),

          const SizedBox(height: 24),

          // --- Save button ---
          // Same ListenableBuilder pattern as LogDoseScreen to enable/disable
          // based on the amount field's content.
          ListenableBuilder(
            listenable: _amountController,
            builder: (context, child) {
              return FilledButton.icon(
                onPressed: _canSave() ? _saveChanges : null,
                icon: const Icon(Icons.check),
                label: const Text('Save Changes'),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Validates the form — same logic as LogDoseScreen._canSave().
  bool _canSave() {
    if (_selectedSubstance == null) return false;
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return false;
    final amount = double.tryParse(amountText);
    return amount != null && amount > 0;
  }

  // Guard against double taps while saving.
  bool _saving = false;

  /// Update the dose log in the database and pop back to the log screen.
  ///
  /// Like a Laravel update action:
  ///   public function update(Request $request, DoseLog $doseLog) {
  ///       $doseLog->update($request->validated());
  ///       return redirect()->back();
  ///   }
  void _saveChanges() async {
    if (_saving) return;
    _saving = true;

    final substance = _selectedSubstance!;
    final amount = double.parse(_amountController.text.trim());

    // Combine date + time into a single DateTime (same as LogDoseScreen).
    final loggedAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Call updateDoseLog() instead of insertDoseLog().
    await ref.read(databaseProvider).updateDoseLog(
      widget.entry.doseLog.id,
      substance.id,
      amount,
      loggedAt,
    );

    _saving = false;

    // Pop back to the log screen. The stream provider will automatically
    // re-emit the updated list, so the changed entry shows up immediately.
    // Like return redirect()->back() in Laravel.
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
