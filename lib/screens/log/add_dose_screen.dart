import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/log/widgets/time_picker.dart';
import 'package:taper/utils/validation.dart';

/// AddDoseScreen = the full form for logging a new dose.
///
/// Like a Laravel create form (doses/create.blade.php).
/// Mirrors EditDoseScreen's layout but with empty defaults:
///   - Trackable picker (dropdown of visible trackables)
///   - Amount (text field with unit suffix)
///   - Time picker (date + time)
///
/// Auto-selects the last-used trackable, falling back to the first visible one.
class AddDoseScreen extends ConsumerStatefulWidget {
  /// Optional pre-fill values for the "copy dose" feature.
  /// When provided, the form opens with these values already set,
  /// but the time defaults to now (like "duplicate" in a CMS).
  final int? initialTrackableId;
  final double? initialAmount;

  /// Optional preset name to pre-fill when copying a dose that came from a preset.
  /// E.g., copying an "Espresso" dose carries the name so the new log also says "Espresso".
  final String? initialName;

  /// Optional date to pre-fill the time picker. Used by the calendar button
  /// in the Log tab to log a dose for a specific past date. When provided,
  /// the time picker starts at noon on that date instead of "now".
  final DateTime? initialDate;

  const AddDoseScreen({
    super.key,
    this.initialTrackableId,
    this.initialAmount,
    this.initialName,
    this.initialDate,
  });

  @override
  ConsumerState<AddDoseScreen> createState() => _AddDoseScreenState();
}

class _AddDoseScreenState extends ConsumerState<AddDoseScreen> {
  Trackable? _selectedTrackable;
  final _amountController = TextEditingController();
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  // Tracks which preset was selected (if any). Set when a chip is tapped,
  // cleared when the user manually edits. Passed to insertDoseLog() so
  // the log entry shows "Espresso" instead of just "63 mg".
  String? _selectedPresetName;

  /// Tracks whether the user has attempted to save.
  /// Controls when "Required" errors appear on the amount field.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _resetTime();

    // Pre-fill preset name when copying a dose that came from a preset.
    _selectedPresetName = widget.initialName;

    // Pre-fill amount when copying a dose.
    // The amount goes into the text controller immediately so the user sees it.
    if (widget.initialAmount != null) {
      final amount = widget.initialAmount!;
      _amountController.text = amount.toStringAsFixed(
        amount == amount.roundToDouble() ? 0 : 1,
      );
    }
  }

  void _resetTime() {
    if (widget.initialDate != null) {
      // Calendar button pre-set: use the provided date at noon
      // so the user sees a reasonable default instead of midnight.
      _selectedDate = widget.initialDate!;
      _selectedTime = const TimeOfDay(hour: 12, minute: 0);
    } else {
      final now = DateTime.now();
      _selectedDate = now;
      _selectedTime = TimeOfDay.fromDateTime(now);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch visible trackables — triggers rebuild when data arrives.
    final trackablesAsync = ref.watch(visibleTrackablesProvider);
    // Watch the last-used trackable ID for auto-selecting the dropdown.
    final lastLoggedIdAsync = ref.watch(lastLoggedTrackableIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Dose'),
      ),
      body: trackablesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (trackables) => _buildForm(
          trackables,
          lastLoggedIdAsync.value,
        ),
      ),
    );
  }

  Widget _buildForm(List<Trackable> trackables, int? lastLoggedTrackableId) {
    if (trackables.isEmpty) {
      return const Center(child: Text('No trackables. Add one first.'));
    }

    // Auto-select logic priority:
    // 1. initialTrackableId (from "copy dose" action) — highest priority
    // 2. lastLoggedTrackableId (most recently used) — convenience default
    // 3. First visible trackable — fallback
    // Like: $selected = $request->input('trackable_id') ?? $lastUsed ?? $trackables->first()
    if (_selectedTrackable == null) {
      if (widget.initialTrackableId != null) {
        _selectedTrackable = trackables
            .where((t) => t.id == widget.initialTrackableId)
            .firstOrNull;
      }
      _selectedTrackable ??= lastLoggedTrackableId != null
          ? trackables.where((t) => t.id == lastLoggedTrackableId).firstOrNull
          : null;
      _selectedTrackable ??= trackables.first;
    }

    // Look up the selected trackable from the current stream data.
    final currentSelected = _selectedTrackable != null
        ? trackables.where((t) => t.id == _selectedTrackable!.id).firstOrNull
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Trackable picker ---
          DropdownButtonFormField<Trackable>(
            initialValue: currentSelected,
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

          // --- Preset chips ---
          // Only shown when presets exist for the selected trackable.
          // Tapping a chip fills the amount field, like quick-fill buttons.
          _buildPresetChips(),

          // --- Amount input ---
          TextField(
            controller: _amountController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Amount',
              suffixText: _selectedTrackable?.unit ?? 'mg',
              border: const OutlineInputBorder(),
              // "Required" only shows after the user taps save with an empty field.
              // Other numeric errors (like ".") show live as the user types.
              errorText: _submitted && _amountController.text.trim().isEmpty
                  ? 'Required'
                  : numericFieldErrorAllowZero(_amountController.text),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            // Clear the preset name when the user manually types —
            // the amount no longer matches the preset exactly.
            // Also triggers rebuild so errorText updates live.
            onChanged: (_) {
              _selectedPresetName = null;
              setState(() {});
            },
          ),

          const SizedBox(height: 16),

          // --- Time picker ---
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
            onPressed: _saveDose,
            icon: const Icon(Icons.check),
            label: const Text('Log Dose'),
          ),
        ],
      ),
    );
  }

  /// Builds preset chips for the currently selected trackable.
  /// Watches presetsProvider reactively — chips update when trackable changes.
  /// Like a dynamic slot in a Vue component that re-renders on prop change.
  Widget _buildPresetChips() {
    if (_selectedTrackable == null) return const SizedBox.shrink();

    final presetsAsync = ref.watch(presetsProvider(_selectedTrackable!.id));

    return presetsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (presetsList) {
        if (presetsList.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: presetsList.map((preset) {
              return ActionChip(
                label: Text('${preset.name} (${preset.amount.toStringAsFixed(0)})'),
                onPressed: () {
                  // Fill the amount field with the preset value.
                  _amountController.text = preset.amount.toStringAsFixed(
                    preset.amount == preset.amount.roundToDouble() ? 0 : 1,
                  );
                  _amountController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _amountController.text.length),
                  );
                  // Remember which preset was tapped so the dose log
                  // stores the name (e.g., "Espresso") alongside the amount.
                  _selectedPresetName = preset.name;
                },
              );
            }).toList(),
          ),
        );
      },
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

  bool _saving = false;

  void _saveDose() async {
    if (_saving) return;
    // Validate — if anything is wrong, mark as submitted so "Required"
    // errors appear, then rebuild. The user sees what needs fixing.
    if (!_canSave()) {
      _submitted = true;
      setState(() {});
      return;
    }
    _saving = true;

    final trackable = _selectedTrackable!;
    final amount = double.parse(_amountController.text.trim());
    final loggedAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    await ref.read(databaseProvider).insertDoseLog(
      trackable.id,
      amount,
      loggedAt,
      name: _selectedPresetName,
    );

    _saving = false;
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
