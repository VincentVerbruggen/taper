import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/data/decay_model.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/dashboard/trackable_log_screen.dart';
import 'package:taper/screens/dashboard/widgets/decay_curve_chart.dart';
import 'package:taper/screens/shared/quick_add_dose_dialog.dart';

/// A card on the dashboard showing a trackable's current status.
///
/// Each card displays:
///   - Trackable name with colored accent
///   - Stats: "42 mg active / 180 mg today" (or just "500 ml today" if no half-life)
///   - Mini decay curve chart (only for trackables with half-life)
///   - Toolbar: Repeat Last, Add Dose, View Log
///
/// Like a Livewire component that independently loads its own data:
///   `<livewire:trackable-card :id="$id" />`
///
/// ConsumerWidget because it watches a Riverpod provider (trackableCardDataProvider).
class TrackableCard extends ConsumerWidget {
  final int trackableId;

  const TrackableCard({super.key, required this.trackableId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardDataAsync = ref.watch(trackableCardDataProvider(trackableId));

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

  /// Builds the fully loaded trackable card.
  Widget _buildCard(BuildContext context, WidgetRef ref, TrackableCardData data) {
    final trackable = data.trackable;
    final trackableColor = Color(trackable.color);
    // Show chart and active stats for any trackable with a decay model.
    // This covers both exponential (caffeine) and linear (alcohol).
    final hasDecay = DecayModel.fromString(trackable.decayModel) != DecayModel.none;

    return Card(
      // Clip content so the left accent border doesn't overlap child widgets.
      clipBehavior: Clip.antiAlias,
      child: Container(
        // Left border accent in the trackable's color — visual identifier.
        // Like a colored tag/badge on a Trello card.
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: trackableColor, width: 4),
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
                  // Trackable name: takes remaining space, truncates with ellipsis.
                  Flexible(
                    child: Text(
                      trackable.name,
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
              // Only shown for trackables with a decay model and non-empty curve.
              if (hasDecay && data.curvePoints.isNotEmpty) ...[
                const SizedBox(height: 12),
                DecayCurveChart(
                  curvePoints: data.curvePoints,
                  color: trackableColor,
                  startTime: data.dayBoundaryTime,
                  // Hide the "now" indicator when viewing past dates.
                  isLive: ref.watch(selectedDateProvider) == null,
                  // Pass threshold lines for dashed horizontal references.
                  thresholds: data.thresholds
                      .map((t) => (name: t.name, amount: t.amount))
                      .toList(),
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

                  // "Add Dose" — opens the quick-add dialog for this trackable.
                  TextButton.icon(
                    onPressed: () => _addDose(context, ref, data.trackable),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Dose'),
                  ),

                  // "View Log" — navigates to the trackable's full history.
                  TextButton.icon(
                    onPressed: () => _viewLog(context, trackable),
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
  String _buildStatsText(TrackableCardData data) {
    final unit = data.trackable.unit;
    final totalStr = data.totalToday.toStringAsFixed(0);
    final hasDecay = DecayModel.fromString(data.trackable.decayModel) != DecayModel.none;

    if (hasDecay) {
      // Show "active / total unit" for trackables with decay tracking.
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
  void _repeatLast(BuildContext context, WidgetRef ref, TrackableCardData data) async {
    final lastDose = data.lastDose!;
    final db = ref.read(databaseProvider);

    // Insert a new dose with the same amount, name, and trackable, timestamped now.
    // Preserves the preset name (e.g., "Espresso") from the original dose.
    final insertedId = await db.insertDoseLog(
      lastDose.trackableId,
      lastDose.amount,
      DateTime.now(),
      name: lastDose.name,
    );

    // Show a SnackBar confirming the action, with an undo button.
    // The undo deletes the specific dose we just inserted (by ID).
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          showCloseIcon: true, // Let users dismiss the snackbar manually
          content: Text(
            'Logged ${lastDose.amount.toStringAsFixed(0)} ${data.trackable.unit} ${data.trackable.name}',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => db.deleteDoseLog(insertedId),
          ),
        ),
      );
    }
  }

  /// Opens the shared quick-add dialog for this trackable.
  /// No navigation — the dialog appears over the dashboard.
  /// Loads presets first so the dialog can show quick-fill chips.
  void _addDose(BuildContext context, WidgetRef ref, Trackable trackable) async {
    final db = ref.read(databaseProvider);
    // Load presets before opening the dialog — one-shot fetch, not a stream.
    // Like: $presets = Preset::where('trackable_id', $id)->orderBy('sort_order')->get()
    final presetsList = await db.getPresets(trackable.id);
    if (!context.mounted) return;
    showQuickAddDoseDialog(
      context: context,
      trackable: trackable,
      db: db,
      presets: presetsList,
    );
  }

  /// Navigate to the full dose history for this trackable.
  void _viewLog(BuildContext context, Trackable trackable) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackableLogScreen(trackable: trackable),
      ),
    );
  }
}
