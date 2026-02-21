import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';

/// LogDoseScreen = the form for recording a substance dose.
///
/// Like a Laravel create form (doses/create.blade.php) with:
///   - A <select> for substance (populated from DB)
///   - An <input type="number"> for amount in mg
///   - A time picker defaulting to "now"
///   - A submit button
///
/// ConsumerStatefulWidget because we need both:
///   - Riverpod providers (ref.watch for substances list, ref.read for DB writes)
///   - Local state (selected substance, amount controller, chosen time)
class LogDoseScreen extends ConsumerStatefulWidget {
  const LogDoseScreen({super.key});

  @override
  ConsumerState<LogDoseScreen> createState() => _LogDoseScreenState();
}

class _LogDoseScreenState extends ConsumerState<LogDoseScreen> {
  // Currently selected substance from the dropdown.
  // null = nothing selected yet. Like: public ?int $substanceId = null;
  Substance? _selectedSubstance;

  // Controller for the amount text field.
  final _amountController = TextEditingController();

  // The chosen time for the dose. Defaults to now, tappable to change.
  // We store both date and time of day separately because Flutter's
  // pickers work with TimeOfDay (just hours/minutes) not full DateTime.
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _resetTime();
  }

  /// Reset the time fields to "right now".
  void _resetTime() {
    final now = DateTime.now();
    _selectedDate = now;
    _selectedTime = TimeOfDay.fromDateTime(now);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final substancesAsync = ref.watch(substancesProvider);

    return Scaffold(
      body: substancesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (substances) => _buildForm(substances),
      ),
    );
  }

  Widget _buildForm(List<Substance> substances) {
    // If there are no substances, show a hint to create one first.
    if (substances.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No substances yet.\nGo to the Substances tab to add one first.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Extra top padding to push content below status bar area.
          const SizedBox(height: 40),

          Text(
            'Log Dose',
            style: Theme.of(context).textTheme.headlineMedium,
          ),

          const SizedBox(height: 24),

          // --- Substance picker ---
          // DropdownButtonFormField = <select> in HTML.
          // Populates from the substances list (reactive via provider).
          DropdownButtonFormField<Substance>(
            initialValue: _selectedSubstance,
            decoration: const InputDecoration(
              labelText: 'Substance',
              border: OutlineInputBorder(),
            ),
            // Build one <option> per substance.
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
          // number keyboard + decimal support. Like <input type="number" step="0.1">.
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Amount',
              suffixText: 'mg',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // Only allow digits and one decimal point.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
          ),

          const SizedBox(height: 16),

          // --- Time picker ---
          // Tappable row that shows the current date + time.
          // Tapping opens Flutter's built-in date/time picker dialogs.
          _TimePicker(
            date: _selectedDate,
            time: _selectedTime,
            onDateChanged: (date) => setState(() => _selectedDate = date),
            onTimeChanged: (time) => setState(() => _selectedTime = time),
          ),

          const SizedBox(height: 24),

          // --- Save button ---
          // ListenableBuilder rebuilds only this button when the amount text changes.
          // Without this, typing in the amount field wouldn't enable/disable the button
          // because TextField changes don't trigger setState on the parent.
          // Same pattern as the SubstanceFormCard's Save button.
          ListenableBuilder(
            listenable: _amountController,
            builder: (context, child) {
              return FilledButton.icon(
                onPressed: _canSave() ? _saveDose : null,
                icon: const Icon(Icons.check),
                label: const Text('Log Dose'),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Validates that the form is ready to submit.
  /// Like Laravel's $request->validate() check.
  bool _canSave() {
    if (_selectedSubstance == null) return false;
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return false;
    final amount = double.tryParse(amountText);
    return amount != null && amount > 0;
  }

  // Guard against double taps while the async save is in progress.
  bool _saving = false;

  /// Save the dose to the database and reset the form.
  void _saveDose() async {
    if (_saving) return;
    _saving = true;

    final substance = _selectedSubstance!;
    final amount = double.parse(_amountController.text.trim());

    // Combine the separate date and time into a single DateTime.
    // Flutter's time picker gives TimeOfDay (hours+minutes only),
    // so we merge it with the selected date.
    final loggedAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    await ref.read(databaseProvider).insertDoseLog(
      substance.id,
      amount,
      loggedAt,
    );

    // Reset form: keep substance selected (convenient for repeat logging),
    // clear amount, reset time to now.
    _amountController.clear();
    _resetTime();
    _saving = false;
    setState(() {});
  }
}

// ---------------------------------------------------------------------------
// Time picker widget
// ---------------------------------------------------------------------------

/// Tappable date + time display that opens picker dialogs.
///
/// Like two <input type="date"> and <input type="time"> side by side,
/// but using Flutter's native Material 3 picker dialogs.
class _TimePicker extends StatelessWidget {
  final DateTime date;
  final TimeOfDay time;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TimeOfDay> onTimeChanged;

  const _TimePicker({
    required this.date,
    required this.time,
    required this.onDateChanged,
    required this.onTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Date chip — tap to open date picker
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickDate(context),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(_formatDate(date)),
          ),
        ),

        const SizedBox(width: 12),

        // Time chip — tap to open time picker
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickTime(context),
            icon: const Icon(Icons.access_time, size: 18),
            label: Text(time.format(context)),
          ),
        ),
      ],
    );
  }

  void _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      // Allow logging up to 7 days in the past (forgot to log yesterday's coffee).
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
    );
    if (picked != null) onDateChanged(picked);
  }

  void _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: time,
    );
    if (picked != null) onTimeChanged(picked);
  }

  /// Format date as "Mon, Feb 21" — short and readable.
  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    // DateTime.weekday: 1=Monday, 7=Sunday. Subtract 1 for 0-indexed array.
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }
}
