import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/log/widgets/time_picker.dart';

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
  const AddDoseScreen({super.key});

  @override
  ConsumerState<AddDoseScreen> createState() => _AddDoseScreenState();
}

class _AddDoseScreenState extends ConsumerState<AddDoseScreen> {
  Trackable? _selectedTrackable;
  final _amountController = TextEditingController();
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _resetTime();
  }

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

    // Auto-select based on the most recently logged trackable.
    // Falls back to the first visible trackable if the last-used one
    // isn't in the visible list (e.g., it was hidden since the last log).
    // Like: $selected = $trackables->firstWhere(fn($t) => $t->id === $lastUsedId) ?? $trackables->first()
    if (_selectedTrackable == null) {
      _selectedTrackable = lastLoggedTrackableId != null
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
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
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
    return amount != null && amount > 0;
  }

  bool _saving = false;

  void _saveDose() async {
    if (_saving) return;
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
    );

    _saving = false;
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
