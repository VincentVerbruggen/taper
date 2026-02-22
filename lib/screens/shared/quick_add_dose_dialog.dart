import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:taper/data/database.dart';
import 'package:taper/screens/log/widgets/time_picker.dart';
import 'package:taper/utils/validation.dart';

/// Shows a quick-add dialog for logging a dose of a specific trackable.
///
/// A lightweight popup with amount field + time picker. Used from:
///   - Dashboard card "Add Dose" button (trackable known from card)
///   - Trackable log screen FAB (trackable known from screen)
///
/// Like a quick-add modal in a web app — enter a number, pick a time, done.
/// Returns the entered amount if logged, null if cancelled.
///
/// [context] — BuildContext for showing the dialog.
/// [trackable] — The trackable to log a dose for (provides name + unit).
/// [db] — Database instance for inserting the dose.
/// [presets] — Optional list of preset chips to show above the amount field.
///   When a chip is tapped, it fills the amount field with the preset's value.
/// [scaffoldContext] — Optional separate context for showing SnackBar
///   (needed when the calling widget's context differs from the Scaffold).
Future<double?> showQuickAddDoseDialog({
  required BuildContext context,
  required Trackable trackable,
  required AppDatabase db,
  List<Preset> presets = const [],
  BuildContext? scaffoldContext,
}) async {
  final amountController = TextEditingController();
  double? result;

  // Tracks which preset was selected (if any). Set when a chip is tapped,
  // cleared when the user manually edits the amount field. Passed to
  // insertDoseLog() so the log entry shows "Espresso" instead of just "63 mg".
  String? selectedPresetName;

  // Initialize time to now — the user can change it via the picker.
  var selectedDate = DateTime.now();
  var selectedTime = TimeOfDay.fromDateTime(selectedDate);

  // Tracks whether the user has attempted to log.
  var submitted = false;

  await showDialog(
    context: context,
    builder: (dialogContext) {
      // StatefulBuilder gives us setState inside the dialog so the time
      // picker buttons can update without needing a separate StatefulWidget.
      // Like using Alpine.js x-data inside a Blade modal.
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Log ${trackable.name}'),
            // Column so we can stack amount + time picker vertically.
            // IntrinsicWidth keeps the dialog from being too wide.
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Preset chips ---
                // Tapping a chip fills the amount field with that preset's value.
                // Like quick-fill buttons in a web calculator form.
                if (presets.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: presets.map((preset) {
                      return ActionChip(
                        label: Text('${preset.name} (${preset.amount.toStringAsFixed(0)})'),
                        onPressed: () {
                          // Fill the amount field with the preset value.
                          amountController.text = preset.amount.toStringAsFixed(
                            // Use integer format if the amount is a whole number,
                            // otherwise show one decimal place.
                            preset.amount == preset.amount.roundToDouble() ? 0 : 1,
                          );
                          // Move cursor to end so user can edit if needed.
                          amountController.selection = TextSelection.fromPosition(
                            TextPosition(offset: amountController.text.length),
                          );
                          // Remember which preset was tapped so the dose log
                          // stores the name (e.g., "Espresso") alongside the amount.
                          selectedPresetName = preset.name;
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: amountController,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  // Only allow digits and decimal point.
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    suffixText: trackable.unit,
                    border: const OutlineInputBorder(),
                    errorText: submitted && amountController.text.trim().isEmpty
                        ? 'Required'
                        : numericFieldError(amountController.text),
                  ),
                  // Clear the preset name when the user manually types —
                  // the amount no longer matches the preset exactly.
                  // Also triggers dialog rebuild so errorText updates live.
                  onChanged: (_) {
                    selectedPresetName = null;
                    setDialogState(() {});
                  },
                  // Submit on keyboard "done" — same as tapping Log.
                  onSubmitted: (_) {
                    final amount =
                        double.tryParse(amountController.text.trim());
                    if (amount != null && amount > 0) {
                      result = amount;
                      Navigator.pop(dialogContext);
                    } else {
                      // Show errors if the field is empty or invalid.
                      submitted = true;
                      setDialogState(() {});
                    }
                  },
                ),

                const SizedBox(height: 16),

                // Time picker — reuses the same TimePicker widget from the
                // full log dose form. Defaults to "now" but user can change.
                TimePicker(
                  date: selectedDate,
                  time: selectedTime,
                  onDateChanged: (date) {
                    setDialogState(() => selectedDate = date);
                  },
                  onTimeChanged: (time) {
                    setDialogState(() => selectedTime = time);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              // Always enabled — shows errors on press instead of disabling.
              TextButton(
                onPressed: () {
                  final amount =
                      double.tryParse(amountController.text.trim());
                  if (amount != null && amount > 0) {
                    result = amount;
                    Navigator.pop(dialogContext);
                  } else {
                    // Show errors if the field is empty or invalid.
                    submitted = true;
                    setDialogState(() {});
                  }
                },
                child: const Text('Log'),
              ),
            ],
          );
        },
      );
    },
  );

  // If the user entered a valid amount, insert the dose and show confirmation.
  if (result != null) {
    final amount = result!;
    // Build the DateTime from the selected date + time.
    final loggedAt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    await db.insertDoseLog(trackable.id, amount, loggedAt, name: selectedPresetName);

    // Show SnackBar using the scaffold context (falls back to the provided context).
    final snackContext = scaffoldContext ?? context;
    if (snackContext.mounted) {
      ScaffoldMessenger.of(snackContext).showSnackBar(
        SnackBar(
          showCloseIcon: true, // Let users dismiss the snackbar manually
          content: Text(
            'Logged ${amount.toStringAsFixed(0)} ${trackable.unit} ${trackable.name}',
          ),
        ),
      );
    }
  }

  return result;
}
