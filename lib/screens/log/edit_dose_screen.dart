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
/// Structurally identical to the create form in LogDoseScreen, but:
///   - Receives the existing entry as a constructor parameter
///   - Pre-fills all fields from the existing data
///   - Save calls updateDoseLog() instead of insertDoseLog()
///   - Navigator.pop() after saving returns to the log list
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
      // AppBar gives us the back button for free — like having a <a href="{{ url()->previous() }}">
      // back link in a Blade layout. Flutter's Navigator handles it automatically.
      appBar: AppBar(
        title: const Text('Edit Dose'),
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
          // Same dropdown as the create form, but with initialValue set
          // to the existing trackable. Like <select> with selected="...".
          DropdownButtonFormField<Trackable>(
            // Pre-select the trackable that matches the existing entry's trackable ID.
            // We find by ID (not reference) because the Trackable objects from the
            // provider stream are different instances than widget.entry.trackable.
            // Like: <option> with @selected($t->id === $doseLog->trackable_id)
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
          // Pre-filled with the existing amount.
          // suffixText shows the trackable's unit dynamically.
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
          // Pre-filled with the existing date/time.
          TimePicker(
            date: _selectedDate,
            time: _selectedTime,
            onDateChanged: (date) => setState(() => _selectedDate = date),
            onTimeChanged: (time) => setState(() => _selectedTime = time),
          ),

          const SizedBox(height: 24),

          // --- Save button ---
          // Always enabled — shows errors on press instead of silently disabling.
          FilledButton.icon(
            onPressed: _saveChanges,
            icon: const Icon(Icons.check),
            label: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  /// Validates the form — allows amount >= 0 (zero = "skipped this dose").
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
  ///
  /// Like a Laravel update action:
  ///   public function update(Request $request, DoseLog $doseLog) {
  ///       $doseLog->update($request->validated());
  ///       return redirect()->back();
  ///   }
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
      trackable.id,
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
