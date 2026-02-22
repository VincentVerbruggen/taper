import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/log/add_dose_screen.dart';
import 'package:taper/screens/log/edit_dose_screen.dart';
import 'package:taper/screens/shared/quick_add_dose_dialog.dart';
import 'package:taper/utils/day_boundary.dart';
import 'package:taper/utils/decay_calculator.dart';

/// Full dose history for a single trackable, with infinite scroll.
///
/// Shows doses grouped by day (using the 5 AM day boundary), with a
/// daily total header and individual dose entries.
///
/// Two modes:
///   1. **All history** (_selectedDate == null) — infinite scroll starting from
///      today, loads 3 more days when scrolling near the bottom.
///   2. **Single day** (_selectedDate != null) — shows only the selected day's
///      doses. Activated by tapping the calendar icon in the AppBar.
///
/// Like a paginated list with an optional date filter:
///   DoseLog::where('trackable_id', $id)
///       ->when($date, fn($q) => $q->whereDate('logged_at', $date))
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
  /// Only used in "all history" mode (_selectedDate == null).
  int _daysLoaded = 3;

  /// When set, filters the view to a single day (the day boundary for that date).
  /// null = show all recent history with infinite scroll.
  /// Like a URL query parameter: /doses?date=2026-02-20 vs /doses (all recent).
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    // Read the configured day boundary hour from settings.
    final boundaryHour = ref.watch(dayBoundaryHourProvider);
    final trackable = widget.trackable;
    final now = DateTime.now();
    final todayBoundary = dayBoundary(now, boundaryHour: boundaryHour);

    // Calculate the query window based on mode.
    // Single day mode: just one day boundary to the next.
    // All history mode: from _daysLoaded ago to end of today.
    final DateTime startBoundary;
    final DateTime endBoundary;

    if (_selectedDate != null) {
      // Single day: query from the selected boundary to the next day's boundary.
      startBoundary = _selectedDate!;
      endBoundary = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day + 1,
        boundaryHour,
      );
    } else {
      // Infinite scroll: recent history.
      endBoundary = nextDayBoundary(now, boundaryHour: boundaryHour);
      startBoundary = dayBoundary(now, boundaryHour: boundaryHour).subtract(
        Duration(days: _daysLoaded - 1),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trackable.name),
            // Show the selected date as a subtitle when filtering by day.
            // Like a breadcrumb: "Caffeine > Yesterday".
            if (_selectedDate != null)
              Text(
                _formatDayLabel(_selectedDate!, todayBoundary),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          // Clear filter button — only visible when a date is selected.
          // Tapping resets to "all history" mode with infinite scroll.
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Show all history',
              onPressed: () => setState(() => _selectedDate = null),
            ),
          // Calendar icon to pick a specific date. Always visible in the
          // top right corner — a bit hidden per the user's preference since
          // you usually don't need to browse the past.
          // Wrapped in Padding to align with the body's 16px horizontal padding.
          // AppBar actions default to ~8px right margin which doesn't match.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.calendar_today),
              tooltip: 'Select date',
              onPressed: () => _showDatePicker(context, boundaryHour),
            ),
          ),
        ],
      ),
      // FAB opens a quick-add dialog for logging a dose without leaving
      // the history screen. Like a "quick add" shortcut in a to-do app.
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
        // Only active in "all history" mode — single day doesn't paginate.
        onNotification: (notification) {
          if (_selectedDate == null &&
              notification is ScrollUpdateNotification &&
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
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _selectedDate != null
                        ? 'No doses logged on this day.'
                        : 'No doses logged yet.',
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

  /// Opens a date picker dialog that switches instantly when a date is tapped
  /// (no OK button needed). Uses CalendarDatePicker in a dialog for immediate
  /// selection — like clicking a date cell in a web calendar filter.
  void _showDatePicker(BuildContext context, int boundaryHour) async {
    final now = DateTime.now();

    // Use the selected date or today as the initial date for the picker.
    final initialDate = _selectedDate != null
        ? DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day)
        : DateTime(now.year, now.month, now.day);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // CalendarDatePicker fires onDateChanged immediately on tap.
                // No OK/Cancel buttons needed — picking a date auto-closes.
                CalendarDatePicker(
                  initialDate: initialDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(now.year, now.month, now.day),
                  onDateChanged: (picked) {
                    // Close the dialog immediately on selection.
                    Navigator.pop(dialogContext);

                    // Convert the picked calendar date to a day boundary.
                    setState(() {
                      _selectedDate = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        boundaryHour,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
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

    // Unified card pattern matching log_dose_screen.dart:
    // Padding > Dismissible > Card(shape: RoundedRectangleBorder(12)) > InkWell > ListTile
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Dismissible(
        key: ValueKey(dose.id),
        direction: DismissDirection.endToStart,
        background: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ),
        onDismissed: (_) => _deleteDoseWithUndo(dose, trackable),
        child: Card(
          shape: shape,
          clipBehavior: Clip.antiAlias, // clips ink to rounded corners
          child: InkWell(
            customBorder: shape,
            onTap: () => _editDose(dose, trackable),
            child: ListTile(
              // Show "Skipped" for zero-dose logs (explicit skip),
              // preset name when available (e.g., "Espresso"),
              // or fall back to raw amount (e.g., "63 mg").
              title: Text(
                dose.amount == 0
                    ? 'Skipped'
                    : dose.name != null
                        ? dose.name!
                        : '${dose.amount.toStringAsFixed(0)} ${trackable.unit}',
              ),
              subtitle: Text(time),
              // Copy button: opens AddDoseScreen pre-filled with this dose's
              // trackable + amount, but with current time.
              trailing: IconButton(
                icon: const Icon(Icons.copy, size: 20),
                tooltip: 'Copy dose',
                onPressed: () => _copyDose(dose),
              ),
            ),
          ),
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
        showCloseIcon: true, // Let users dismiss the snackbar manually
        content: Text(
          'Deleted ${dose.amount.toStringAsFixed(0)} ${trackable.unit}',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // Re-insert with the same trackable, amount, timestamp, and preset name.
            db.insertDoseLog(dose.trackableId, dose.amount, dose.loggedAt, name: dose.name);
          },
        ),
      ),
    );
  }

  /// Copy a dose: opens AddDoseScreen pre-filled with this dose's trackable + amount.
  /// Time defaults to now — like duplicating a row but with a fresh timestamp.
  void _copyDose(DoseLog dose) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddDoseScreen(
          initialTrackableId: dose.trackableId,
          initialAmount: dose.amount,
          initialName: dose.name,
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
