import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:taper/data/database.dart';
import 'package:taper/screens/log/widgets/time_picker.dart';

/// Shows a quick-add dialog for logging a dose of a specific substance.
///
/// A lightweight popup with amount field + time picker. Used from:
///   - Dashboard card "Add Dose" button (substance known from card)
///   - Substance log screen FAB (substance known from screen)
///
/// Like a quick-add modal in a web app — enter a number, pick a time, done.
/// Returns the entered amount if logged, null if cancelled.
///
/// [context] — BuildContext for showing the dialog.
/// [substance] — The substance to log a dose for (provides name + unit).
/// [db] — Database instance for inserting the dose.
/// [scaffoldContext] — Optional separate context for showing SnackBar
///   (needed when the calling widget's context differs from the Scaffold).
Future<double?> showQuickAddDoseDialog({
  required BuildContext context,
  required Substance substance,
  required AppDatabase db,
  BuildContext? scaffoldContext,
}) async {
  final amountController = TextEditingController();
  double? result;

  // Initialize time to now — the user can change it via the picker.
  var selectedDate = DateTime.now();
  var selectedTime = TimeOfDay.fromDateTime(selectedDate);

  await showDialog(
    context: context,
    builder: (dialogContext) {
      // StatefulBuilder gives us setState inside the dialog so the time
      // picker buttons can update without needing a separate StatefulWidget.
      // Like using Alpine.js x-data inside a Blade modal.
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Log ${substance.name}'),
            // Column so we can stack amount + time picker vertically.
            // IntrinsicWidth keeps the dialog from being too wide.
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                    suffixText: substance.unit,
                    border: const OutlineInputBorder(),
                  ),
                  // Submit on keyboard "done" — same as tapping Log.
                  onSubmitted: (_) {
                    final amount =
                        double.tryParse(amountController.text.trim());
                    if (amount != null && amount > 0) {
                      result = amount;
                      Navigator.pop(dialogContext);
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
              // ListenableBuilder makes Log button disabled until valid.
              ListenableBuilder(
                listenable: amountController,
                builder: (context, _) {
                  final amount =
                      double.tryParse(amountController.text.trim());
                  final isValid = amount != null && amount > 0;
                  return TextButton(
                    onPressed: isValid
                        ? () {
                            result = amount;
                            Navigator.pop(dialogContext);
                          }
                        : null,
                    child: const Text('Log'),
                  );
                },
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
    await db.insertDoseLog(substance.id, amount, loggedAt);

    // Show SnackBar using the scaffold context (falls back to the provided context).
    final snackContext = scaffoldContext ?? context;
    if (snackContext.mounted) {
      ScaffoldMessenger.of(snackContext).showSnackBar(
        SnackBar(
          content: Text(
            'Logged ${amount.toStringAsFixed(0)} ${substance.unit} ${substance.name}',
          ),
        ),
      );
    }
  }

  return result;
}
