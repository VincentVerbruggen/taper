import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/dashboard/substance_log_screen.dart';
import 'package:taper/screens/dashboard/widgets/decay_curve_chart.dart';
import 'package:taper/screens/shared/quick_add_dose_dialog.dart';

/// A card on the dashboard showing a substance's current status.
///
/// Each card displays:
///   - Substance name with colored accent
///   - Stats: "42 mg active / 180 mg today" (or just "500 ml today" if no half-life)
///   - Mini decay curve chart (only for substances with half-life)
///   - Toolbar: Repeat Last, Add Dose, View Log
///
/// Like a Livewire component that independently loads its own data:
///   `<livewire:substance-card :id="$id" />`
///
/// ConsumerWidget because it watches a Riverpod provider (substanceCardDataProvider).
class SubstanceCard extends ConsumerWidget {
  final int substanceId;

  const SubstanceCard({super.key, required this.substanceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardDataAsync = ref.watch(substanceCardDataProvider(substanceId));

    return cardDataAsync.when(
      // Loading state: colored shimmer placeholder.
      // Shows a minimal skeleton while the DB query runs.
      loading: () => _buildLoadingSkeleton(context),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $error'),
        ),
      ),
      data: (data) => _buildCard(context, ref, data),
    );
  }

  /// Builds the skeleton/shimmer while data loads.
  /// Simple colored containers that hint at the card layout.
  Widget _buildLoadingSkeleton(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title placeholder.
            Container(
              width: 120,
              height: 20,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            // Stats placeholder.
            Container(
              width: 200,
              height: 14,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the fully loaded substance card.
  Widget _buildCard(BuildContext context, WidgetRef ref, SubstanceCardData data) {
    final substance = data.substance;
    final substanceColor = Color(substance.color);
    final hasHalfLife = substance.halfLifeHours != null;

    return Card(
      // Clip content so the left accent border doesn't overlap child widgets.
      clipBehavior: Clip.antiAlias,
      child: Container(
        // Left border accent in the substance's color — visual identifier.
        // Like a colored tag/badge on a Trello card.
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: substanceColor, width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Compact title row: name left, stats right ---
              // "Caffeine     42 / 180 mg" (with half-life)
              // "Water            500 ml"  (without half-life)
              // Like a table row with name and summary in one line.
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // Substance name: takes remaining space, truncates with ellipsis.
                  Flexible(
                    child: Text(
                      substance.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Stats summary: aligned right, doesn't shrink.
                  Text(
                    _buildStatsText(data),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              // --- Mini decay curve chart ---
              // Only shown for substances with a half-life and non-empty curve.
              if (hasHalfLife && data.curvePoints.isNotEmpty) ...[
                const SizedBox(height: 12),
                DecayCurveChart(
                  curvePoints: data.curvePoints,
                  color: substanceColor,
                  startTime: data.dayBoundaryTime,
                ),
              ],

              const SizedBox(height: 8),

              // --- Toolbar row ---
              // Action buttons: Repeat Last (conditional), Add Dose, View Log.
              // Wrapped in a Row with wrap for narrow screens.
              Wrap(
                spacing: 8,
                children: [
                  // "Repeat Last" — only shown if there's a previous dose.
                  // Inserts the same amount immediately, with undo via SnackBar.
                  if (data.lastDose != null)
                    TextButton.icon(
                      onPressed: () => _repeatLast(context, ref, data),
                      icon: const Icon(Icons.replay, size: 18),
                      label: const Text('Repeat Last'),
                    ),

                  // "Add Dose" — opens the quick-add dialog for this substance.
                  TextButton.icon(
                    onPressed: () => _addDose(context, ref, data.substance),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Dose'),
                  ),

                  // "View Log" — navigates to the substance's full history.
                  TextButton.icon(
                    onPressed: () => _viewLog(context, substance),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('View Log'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the compact stats text for the title row.
  ///
  /// Two formats:
  ///   WITH half-life: "42 / 180 mg" (active / total unit)
  ///   WITHOUT half-life: "500 ml" (total unit)
  String _buildStatsText(SubstanceCardData data) {
    final unit = data.substance.unit;
    final totalStr = data.totalToday.toStringAsFixed(0);

    if (data.substance.halfLifeHours != null) {
      final activeStr = data.activeAmount.toStringAsFixed(0);
      return '$activeStr / $totalStr $unit';
    } else {
      return '$totalStr $unit';
    }
  }

  /// Repeat the last dose: insert immediately, show SnackBar with undo.
  ///
  /// Captures the inserted ID so the undo action can delete it by ID.
  /// Like a flash message with an undo link in a web app.
  void _repeatLast(BuildContext context, WidgetRef ref, SubstanceCardData data) async {
    final lastDose = data.lastDose!;
    final db = ref.read(databaseProvider);

    // Insert a new dose with the same amount and substance, timestamped now.
    final insertedId = await db.insertDoseLog(
      lastDose.substanceId,
      lastDose.amount,
      DateTime.now(),
    );

    // Show a SnackBar confirming the action, with an undo button.
    // The undo deletes the specific dose we just inserted (by ID).
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logged ${lastDose.amount.toStringAsFixed(0)} ${data.substance.unit} ${data.substance.name}',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => db.deleteDoseLog(insertedId),
          ),
        ),
      );
    }
  }

  /// Opens the shared quick-add dialog for this substance.
  /// No navigation — the dialog appears over the dashboard.
  void _addDose(BuildContext context, WidgetRef ref, Substance substance) {
    final db = ref.read(databaseProvider);
    showQuickAddDoseDialog(
      context: context,
      substance: substance,
      db: db,
    );
  }

  /// Navigate to the full dose history for this substance.
  void _viewLog(BuildContext context, Substance substance) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubstanceLogScreen(substance: substance),
      ),
    );
  }
}
