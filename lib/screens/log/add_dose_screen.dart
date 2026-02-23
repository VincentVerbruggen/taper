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
/// Unified header pattern: Back arrow | Title | Checkmark (Save).
class AddDoseScreen extends ConsumerStatefulWidget {
  /// Optional pre-fill values for the "copy dose" feature.
  final int? initialTrackableId;
  final double? initialAmount;
  final String? initialName;
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
  String? _selectedPresetName;

  /// Tracks whether the user has attempted to save.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _resetTime();
    _selectedPresetName = widget.initialName;

    if (widget.initialAmount != null) {
      final amount = widget.initialAmount!;
      _amountController.text = amount.toStringAsFixed(
        amount == amount.roundToDouble() ? 0 : 1,
      );
    }
  }

  void _resetTime() {
    if (widget.initialDate != null) {
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
    final trackablesAsync = ref.watch(visibleTrackablesProvider);
    final lastLoggedIdAsync = ref.watch(lastLoggedTrackableIdProvider);

    return Scaffold(
      // Unified AppBar pattern: Title + Checkmark action.
      appBar: AppBar(
        title: const Text('Log Dose'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Log Dose',
            onPressed: _saveDose,
          ),
        ],
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
          _buildPresetChips(),

          // --- Amount input ---
          TextField(
            controller: _amountController,
            autofocus: true,
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

          // Note: Save button moved to AppBar actions for UI consistency.
        ],
      ),
    );
  }

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
                  _amountController.text = preset.amount.toStringAsFixed(
                    preset.amount == preset.amount.roundToDouble() ? 0 : 1,
                  );
                  _amountController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _amountController.text.length),
                  );
                  _selectedPresetName = preset.name;
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

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
