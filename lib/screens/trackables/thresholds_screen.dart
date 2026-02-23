// hide Threshold to avoid clash with our database's Threshold model.
// Flutter's Threshold is a Curve subclass from animations — not used here.
import 'package:flutter/material.dart' hide Threshold;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/utils/validation.dart';

/// Dedicated screen for managing thresholds for a trackable.
///
/// Thresholds = named horizontal reference lines on the decay chart (e.g.,
/// "Daily max" = 400 mg). Same CRUD pattern as PresetsScreen.
///
/// Each threshold has a comparison type:
///   - Daily Total: compares against cumulative intake today (shown in Total Focus mode)
///   - Active Amount: compares against what's currently in your system (shown in Decay Focus mode)
///
/// Like a Laravel resource controller for thresholds:
///   Route::resource('trackables/{trackable}/thresholds', ThresholdController::class)
class ThresholdsScreen extends ConsumerWidget {
  /// The trackable whose thresholds we're managing.
  final Trackable trackable;

  const ThresholdsScreen({super.key, required this.trackable});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch thresholds reactively — list updates instantly on add/edit/delete.
    final thresholdsAsync = ref.watch(thresholdsProvider(trackable.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thresholds'),
      ),
      // FAB to add a new threshold.
      floatingActionButton: FloatingActionButton(
        heroTag: 'thresholdsFab',
        onPressed: () => _showAddThresholdDialog(
          context,
          ref,
          thresholdsAsync.value?.map((t) => t.name).toList() ?? [],
        ),
        child: const Icon(Icons.add),
      ),
      body: thresholdsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error loading thresholds: $e')),
        data: (thresholdsList) {
          if (thresholdsList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No thresholds yet.\nTap + to add one.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: thresholdsList.length,
            itemBuilder: (context, index) {
              final threshold = thresholdsList[index];
              // Exclude this threshold's name for duplicate checking in edit dialog.
              final otherNames = thresholdsList
                  .where((t) => t.id != threshold.id)
                  .map((t) => t.name)
                  .toList();
              final shape = RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              );
              // Human-readable label for the comparison type.
              final typeLabel = threshold.comparisonType == 'active_amount'
                  ? 'Active Amount'
                  : 'Daily Total';
              return Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Card(
                  shape: shape,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    customBorder: shape,
                    onTap: () => _showEditThresholdDialog(
                      context,
                      ref,
                      threshold,
                      otherNames,
                    ),
                    child: ListTile(
                      title: Text(threshold.name),
                      subtitle: Text(
                        '${threshold.amount.toStringAsFixed(0)} ${trackable.unit} · $typeLabel',
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () {
                          ref.read(databaseProvider).deleteThreshold(threshold.id);
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Shows a dialog to add a new threshold (name + amount + comparison type).
  void _showAddThresholdDialog(
    BuildContext context,
    WidgetRef ref,
    List<String> existingNames,
  ) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    // Default comparison type — "daily_total" for backward compatibility.
    var comparisonType = 'daily_total';
    var submitted = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final nameError = submitted && nameController.text.trim().isEmpty
                ? 'Required'
                : duplicateNameError(nameController.text, existingNames);
            final amountError = submitted && amountController.text.trim().isEmpty
                ? 'Required'
                : numericFieldError(amountController.text);

            return AlertDialog(
              title: const Text('Add Threshold'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Daily max',
                      border: const OutlineInputBorder(),
                      errorText: nameError,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      suffixText: trackable.unit,
                      border: const OutlineInputBorder(),
                      errorText: amountError,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  // Comparison type selector — determines what the threshold
                  // compares against on the chart. Like a radio group in HTML.
                  _buildComparisonTypeSelector(
                    comparisonType,
                    (value) => setDialogState(() => comparisonType = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final amount =
                        double.tryParse(amountController.text.trim());
                    if (name.isEmpty ||
                        duplicateNameError(name, existingNames) != null ||
                        amount == null ||
                        amount <= 0) {
                      submitted = true;
                      setDialogState(() {});
                      return;
                    }
                    ref.read(databaseProvider).insertThreshold(
                      trackable.id,
                      name,
                      amount,
                      comparisonType: comparisonType,
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Shows a dialog to edit an existing threshold's name, amount, and comparison type.
  void _showEditThresholdDialog(
    BuildContext context,
    WidgetRef ref,
    Threshold threshold,
    List<String> existingNames,
  ) {
    final nameController = TextEditingController(text: threshold.name);
    final amountController = TextEditingController(
      text: threshold.amount.toStringAsFixed(
        threshold.amount == threshold.amount.roundToDouble() ? 0 : 1,
      ),
    );
    var comparisonType = threshold.comparisonType;
    var submitted = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final nameError = submitted && nameController.text.trim().isEmpty
                ? 'Required'
                : duplicateNameError(nameController.text, existingNames);
            final amountError = submitted && amountController.text.trim().isEmpty
                ? 'Required'
                : numericFieldError(amountController.text);

            return AlertDialog(
              title: const Text('Edit Threshold'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: const OutlineInputBorder(),
                      errorText: nameError,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      suffixText: trackable.unit,
                      border: const OutlineInputBorder(),
                      errorText: amountError,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  _buildComparisonTypeSelector(
                    comparisonType,
                    (value) => setDialogState(() => comparisonType = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final amount =
                        double.tryParse(amountController.text.trim());
                    if (name.isEmpty ||
                        duplicateNameError(name, existingNames) != null ||
                        amount == null ||
                        amount <= 0) {
                      submitted = true;
                      setDialogState(() {});
                      return;
                    }
                    ref.read(databaseProvider).updateThreshold(
                      threshold.id,
                      name: name,
                      amount: amount,
                      comparisonType: comparisonType,
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Segmented button for choosing the comparison type.
  ///
  /// "Daily Total" = threshold compared against cumulative intake today.
  /// "Active Amount" = threshold compared against active (in-system) amount.
  ///
  /// Like a radio group in HTML:
  ///   <input type="radio" name="comparison" value="daily_total" />
  ///   <input type="radio" name="comparison" value="active_amount" />
  Widget _buildComparisonTypeSelector(
    String currentValue,
    ValueChanged<String> onChanged,
  ) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'daily_total',
          label: Text('Daily Total'),
          icon: Icon(Icons.bar_chart, size: 18),
        ),
        ButtonSegment(
          value: 'active_amount',
          label: Text('Active Amount'),
          icon: Icon(Icons.show_chart, size: 18),
        ),
      ],
      selected: {currentValue},
      onSelectionChanged: (selection) => onChanged(selection.first),
      // Single selection — exactly one type must be active.
      multiSelectionEnabled: false,
    );
  }
}
