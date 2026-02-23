import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/log/widgets/time_picker.dart';
import 'package:taper/utils/validation.dart';

/// EditDoseScreen = the form for editing an existing dose log.
///
/// Like a Laravel edit form (doses/{id}/edit.blade.php) that receives
/// the existing model via route-model binding:
///   public function edit(DoseLog $doseLog) { return view('doses.edit', compact('doseLog')); }
///
/// Unified header pattern: Back arrow | Title | Checkmark (Save).
/// Like a standard Material 3 edit toolbar.
class EditDoseScreen extends ConsumerStatefulWidget {
  /// The dose log entry to edit — includes both the DoseLog and its Trackable.
  /// Like passing $doseLog->load('trackable') to the view.
  final DoseLogWithTrackable entry;

  const EditDoseScreen({super.key, required this.entry});

  @override
  ConsumerState<EditDoseScreen> createState() => _EditDoseScreenState();
}

class _EditDoseScreenState extends ConsumerState<EditDoseScreen> {
  // Currently selected trackable — pre-filled from the existing entry.
  Trackable? _selectedTrackable;

  // Controller for the amount text field — pre-filled with existing amount.
  final _amountController = TextEditingController();

  // Date and time — pre-filled from the existing loggedAt timestamp.
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  /// Tracks whether the user has attempted to save.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();

    // Pre-fill all form fields from the existing entry.
    // Like old() in Laravel Blade — populates inputs with previous values.
    _selectedTrackable = widget.entry.trackable;
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
    // Watch the trackables list so the dropdown stays in sync if trackables
    // change while the edit screen is open (unlikely but defensive).
    final trackablesAsync = ref.watch(trackablesProvider);

    return Scaffold(
      // Unified AppBar pattern: Title + Checkmark action.
      // Back button is automatic in Flutter's standard AppBar.
      appBar: AppBar(
        title: const Text('Edit Dose'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save changes',
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: trackablesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (trackables) => _buildForm(trackables),
      ),
    );
  }

  Widget _buildForm(List<Trackable> trackables) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Trackable picker ---
          DropdownButtonFormField<Trackable>(
            // Pre-select the trackable that matches the existing entry's trackable ID.
            initialValue: trackables.where((t) => t.id == _selectedTrackable?.id).firstOrNull,
            decoration: const InputDecoration(
              labelText: 'Trackable',
              border: OutlineInputBorder(),
            ),
            items: trackables.map((t) {
              return DropdownMenuItem<Trackable>(
                value: t,
                child: Text(t.name),
              );
            }).toList(),
            onChanged: (trackable) {
              setState(() => _selectedTrackable = trackable);
            },
          ),

          const SizedBox(height: 16),

          // --- Amount input ---
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Amount',
              suffixText: _selectedTrackable?.unit ?? 'mg',
              border: const OutlineInputBorder(),
              errorText: _submitted && _amountController.text.trim().isEmpty
                  ? 'Required'
                  : numericFieldErrorAllowZero(_amountController.text),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 16),

          // --- Time picker ---
          TimePicker(
            date: _selectedDate,
            time: _selectedTime,
            onDateChanged: (date) => setState(() => _selectedDate = date),
            onTimeChanged: (time) => setState(() => _selectedTime = time),
          ),
          
          // Note: Save button moved to AppBar actions for UI consistency.
        ],
      ),
    );
  }

  /// Validates the form — allows amount >= 0.
  bool _canSave() {
    if (_selectedTrackable == null) return false;
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return false;
    final amount = double.tryParse(amountText);
    return amount != null && amount >= 0;
  }

  // Guard against double taps while saving.
  bool _saving = false;

  /// Update the dose log in the database and pop back to the log screen.
  void _saveChanges() async {
    if (_saving) return;
    if (!_canSave()) {
      _submitted = true;
      setState(() {});
      return;
    }
    _saving = true;

    final trackable = _selectedTrackable!;
    final amount = double.parse(_amountController.text.trim());

    // Combine date + time into a single DateTime.
    final loggedAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    await ref.read(databaseProvider).updateDoseLog(
      widget.entry.doseLog.id,
      trackable.id,
      amount,
      loggedAt,
    );

    _saving = false;

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
