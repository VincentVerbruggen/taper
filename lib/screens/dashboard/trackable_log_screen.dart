import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/log/edit_dose_screen.dart';
import 'package:taper/screens/shared/quick_add_dose_dialog.dart';
import 'package:taper/utils/day_boundary.dart';
import 'package:taper/utils/decay_calculator.dart';

/// Full dose history for a single trackable, with infinite scroll.
///
/// Shows doses grouped by day (using the 5 AM day boundary), with a
/// daily total header and individual dose entries.
///
/// Starts with 3 days loaded, adds 3 more when scrolling near the bottom.
/// Uses StreamBuilder directly (not a Riverpod provider) because the query
/// range changes with local state (_daysLoaded).
///
/// Like a paginated list in a web app:
///   DoseLog::where('trackable_id', $id)
///       ->whereBetween('logged_at', [$start, $end])
///       ->orderByDesc('logged_at')
///       ->get()
///       ->groupBy(fn($d) => $d->logged_at->format('Y-m-d'))
class TrackableLogScreen extends ConsumerStatefulWidget {
  final Trackable trackable;

  const TrackableLogScreen({super.key, required this.trackable});

  @override
  ConsumerState<TrackableLogScreen> createState() => _TrackableLogScreenState();
}

class _TrackableLogScreenState extends ConsumerState<TrackableLogScreen> {
  /// How many days of history to load. Starts at 3, grows by 3 on scroll.
  /// Like a cursor-based pagination offset.
  int _daysLoaded = 3;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    // Read the configured day boundary hour from settings.
    final boundaryHour = ref.watch(dayBoundaryHourProvider);
    final trackable = widget.trackable;
    final now = DateTime.now();

    // Calculate the query window based on _daysLoaded.
    // End = next day boundary (end of "today").
    // Start = _daysLoaded day boundaries back.
    final endBoundary = nextDayBoundary(now, boundaryHour: boundaryHour);
    final startBoundary = dayBoundary(now, boundaryHour: boundaryHour).subtract(
      Duration(days: _daysLoaded - 1),
    );

    return Scaffold(
      appBar: AppBar(title: Text(trackable.name)),
      // FAB opens a quick-add dialog for logging a dose without leaving
      // the history screen. Like a "quick add" shortcut in a to-do app.
      // FAB opens the shared quick-add dialog for this trackable.
      // Loads presets first so the dialog can show quick-fill chips.
      floatingActionButton: FloatingActionButton(
        heroTag: 'trackableLogFab',
        onPressed: () async {
          final presetsList = await db.getPresets(trackable.id);
          if (!context.mounted) return;
          showQuickAddDoseDialog(
            context: context,
            trackable: trackable,
            db: db,
            presets: presetsList,
          );
        },
        child: const Icon(Icons.add),
      ),
      body: NotificationListener<ScrollNotification>(
        // When the user scrolls near the bottom, load more days.
        // Like IntersectionObserver in JS triggering "load more" pagination.
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification &&
              notification.metrics.extentAfter < 200) {
            setState(() => _daysLoaded += 3);
          }
          return false; // Don't consume the notification.
        },
        child: StreamBuilder<List<DoseLog>>(
          // Watch doses within the current window. The stream re-emits
          // when doses are added/deleted within this range.
          stream: db.watchDosesBetween(trackable.id, startBoundary, endBoundary),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final doses = snapshot.data ?? [];

            if (doses.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No doses logged yet.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            // Group doses by day boundary.
            // Like: $doses->groupBy(fn($d) => dayBoundary($d->logged_at))
            final grouped = _groupByDay(doses, boundaryHour);

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              // Each group = 1 header + N dose items.
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final entry = grouped.entries.elementAt(index);
                return _buildDayGroup(context, entry.key, entry.value, trackable);
              },
            );
          },
        ),
      ),
    );
  }

  /// Groups doses by their day boundary cutoff.
  ///
  /// Returns a LinkedHashMap (insertion-ordered) so days appear in
  /// reverse chronological order (most recent first).
  /// Like: Collection::groupBy() in Laravel, preserving order.
  Map<DateTime, List<DoseLog>> _groupByDay(List<DoseLog> doses, int boundaryHour) {
    final grouped = <DateTime, List<DoseLog>>{};
    for (final dose in doses) {
      final boundary = dayBoundary(dose.loggedAt, boundaryHour: boundaryHour);
      grouped.putIfAbsent(boundary, () => []).add(dose);
    }
    return grouped;
  }

  /// Builds a day group: header (date + daily total) + individual dose entries.
  Widget _buildDayGroup(
    BuildContext context,
    DateTime boundary,
    List<DoseLog> doses,
    Trackable trackable,
  ) {
    final total = DecayCalculator.totalRawAmount(doses);
    final now = DateTime.now();
    final boundaryHour = ref.watch(dayBoundaryHourProvider);
    final todayBoundary = dayBoundary(now, boundaryHour: boundaryHour);

    // Format the day label: "Today", "Yesterday", or "Wed, Feb 19".
    final dayLabel = _formatDayLabel(boundary, todayBoundary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Day header ---
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dayLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Daily total — e.g., "270 mg".
              Text(
                '${total.toStringAsFixed(0)} ${trackable.unit}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // --- Individual dose entries ---
        ...doses.map((dose) => _buildDoseEntry(context, dose, trackable)),

        const SizedBox(height: 8),
      ],
    );
  }

  /// Formats a day boundary into a readable label.
  String _formatDayLabel(DateTime boundary, DateTime todayBoundary) {
    if (boundary == todayBoundary) return 'Today';

    final yesterdayBoundary = todayBoundary.subtract(const Duration(days: 1));
    if (boundary == yesterdayBoundary) return 'Yesterday';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[boundary.weekday - 1]}, ${months[boundary.month - 1]} ${boundary.day}';
  }

  /// Builds a single dose entry row wrapped in Dismissible for swipe-to-delete.
  ///
  /// Same pattern as LogDoseScreen._buildLogTile() — swipe left reveals red
  /// background, dismisses the card, then shows an "Undo" SnackBar.
  Widget _buildDoseEntry(BuildContext context, DoseLog dose, Trackable trackable) {
    // 24h NATO format: "14:30" instead of locale-dependent AM/PM.
    final h = dose.loggedAt.hour.toString().padLeft(2, '0');
    final m = dose.loggedAt.minute.toString().padLeft(2, '0');
    final time = '$h:$m';

    return Dismissible(
      key: ValueKey(dose.id),
      direction: DismissDirection.endToStart,
      background: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Theme.of(context).colorScheme.error,
          child: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.onError,
          ),
        ),
      ),
      onDismissed: (_) => _deleteDoseWithUndo(dose, trackable),
      child: Card.outlined(
        child: ListTile(
          // "90 mg at 2:45 PM"
          title: Text('${dose.amount.toStringAsFixed(0)} ${trackable.unit}'),
          subtitle: Text(time),
          onTap: () => _editDose(dose, trackable),
        ),
      ),
    );
  }

  /// Delete a dose and show an "Undo" SnackBar.
  /// Stores dose details before deleting so we can re-insert on undo.
  void _deleteDoseWithUndo(DoseLog dose, Trackable trackable) async {
    final db = ref.read(databaseProvider);
    await db.deleteDoseLog(dose.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deleted ${dose.amount.toStringAsFixed(0)} ${trackable.unit}',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            db.insertDoseLog(dose.trackableId, dose.amount, dose.loggedAt);
          },
        ),
      ),
    );
  }

  /// Navigate to the edit screen for this dose.
  void _editDose(DoseLog dose, Trackable trackable) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditDoseScreen(
          entry: DoseLogWithTrackable(doseLog: dose, trackable: trackable),
        ),
      ),
    );
  }
}
