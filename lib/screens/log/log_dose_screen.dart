import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/log/add_dose_screen.dart';
import 'package:taper/screens/log/edit_dose_screen.dart';
import 'package:taper/utils/day_boundary.dart';

/// LogDoseScreen = the "Log" tab showing only the currently selected day.
///
/// The selected day is shared across log surfaces via selectedDateProvider:
///   - null  => today (live)
///   - date  => that historical day
///
/// Like a Laravel index route with a global day filter:
///   DoseLog::with('trackable')
///       ->whereBetween('logged_at', [$startBoundary, $endBoundary))
///       ->latest('logged_at')
///       ->get();
class LogDoseScreen extends ConsumerStatefulWidget {
  const LogDoseScreen({super.key});

  @override
  ConsumerState<LogDoseScreen> createState() => _LogDoseScreenState();
}

class _LogDoseScreenState extends ConsumerState<LogDoseScreen> {
  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(selectedDayDoseLogsProvider);
    final boundaryHour = ref.watch(dayBoundaryHourProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    // Provider-driven clock keeps date labels deterministic in widget tests.
    final now = ref.watch(nowProvider)();
    final todayBoundary = dayBoundary(now, boundaryHour: boundaryHour);
    final selectedBoundary = selectedDate != null
        ? DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            boundaryHour,
          )
        : todayBoundary;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'logDoseFab',
        // When viewing a past date, prefill the Add Dose form to that day.
        onPressed: () => _addDose(selectedBoundary),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: false,
        child: logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (logs) => _buildLogsList(
            logs: logs,
            selectedBoundary: selectedBoundary,
            todayBoundary: todayBoundary,
            boundaryHour: boundaryHour,
          ),
        ),
      ),
    );
  }

  Widget _buildLogsList({
    required List<DoseLogWithTrackable> logs,
    required DateTime selectedBoundary,
    required DateTime todayBoundary,
    required int boundaryHour,
  }) {
    final items = <Widget>[
      _buildHeader(
        selectedBoundary: selectedBoundary,
        todayBoundary: todayBoundary,
        boundaryHour: boundaryHour,
      ),
      const SizedBox(height: 8),
    ];

    if (logs.isEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Text(
            'No doses logged on this day.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
      return ListView(padding: const EdgeInsets.all(16), children: items);
    }

    for (final entry in logs) {
      items.add(_buildLogTile(entry));
    }

    return ListView(padding: const EdgeInsets.all(16), children: items);
  }

  /// Header with title + shared day navigation controls.
  ///
  /// This mirrors the dashboard navigation UX so both tabs feel like two views
  /// over the same selected day.
  Widget _buildHeader({
    required DateTime selectedBoundary,
    required DateTime todayBoundary,
    required int boundaryHour,
  }) {
    final isToday = selectedBoundary == todayBoundary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Log', style: Theme.of(context).textTheme.headlineMedium),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  tooltip: 'Select date',
                  onPressed: () => _showDatePicker(boundaryHour),
                ),
                if (!isToday)
                  IconButton(
                    icon: const Icon(Icons.today),
                    tooltip: 'Go to today',
                    onPressed: () {
                      ref.read(selectedDateProvider.notifier).goToToday();
                    },
                  ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous day',
              onPressed: () {
                ref.read(selectedDateProvider.notifier).previousDay();
              },
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showDatePicker(boundaryHour),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Text(
                    _formatDayLabel(selectedBoundary, todayBoundary),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next day',
              // Can't move past today. selectedDateProvider uses null for that.
              onPressed: isToday
                  ? null
                  : () => ref.read(selectedDateProvider.notifier).nextDay(),
            ),
          ],
        ),
      ],
    );
  }

  /// Opens a calendar picker and immediately applies the tapped day.
  ///
  /// This keeps the day switch one-tap (no extra OK button), like the
  /// trackable log calendar UX.
  Future<void> _showDatePicker(int boundaryHour) async {
    final now = ref.read(nowProvider)();
    final selectedDate = ref.read(selectedDateProvider);
    final initialDate = selectedDate != null
        ? DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
        : DateTime(now.year, now.month, now.day);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: CalendarDatePicker(
              initialDate: initialDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(now.year, now.month, now.day),
              onDateChanged: (picked) {
                Navigator.pop(dialogContext);
                ref
                    .read(selectedDateProvider.notifier)
                    .selectDate(
                      DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        boundaryHour,
                      ),
                    );
              },
            ),
          ),
        );
      },
    );
  }

  /// Builds a single log entry card.
  Widget _buildLogTile(DoseLogWithTrackable entry) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Card(
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: shape,
          onTap: () => _editDoseLog(entry),
          child: ListTile(
            // Show "Skipped" for zero-dose logs (explicit skip),
            // preset name when available (e.g., "Caffeine — Espresso"),
            // or fall back to raw amount (e.g., "Caffeine — 63 mg").
            title: Text(
              entry.doseLog.amount == 0
                  ? '${entry.trackable.name} — Skipped'
                  : entry.doseLog.name != null
                  ? '${entry.trackable.name} — ${entry.doseLog.name!} (${entry.doseLog.amount.toStringAsFixed(0)} ${entry.trackable.unit})'
                  : '${entry.trackable.name} — ${entry.doseLog.amount.toStringAsFixed(0)} ${entry.trackable.unit}',
            ),
            subtitle: Text(
              entry.doseLog.isPlanned
                  ? '${_formatLogTime(entry.doseLog.loggedAt)} • Planned'
                  : _formatLogTime(entry.doseLog.loggedAt),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: 'Copy dose',
                  onPressed: () => _copyDose(entry),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Delete dose',
                  onPressed: () => _deleteDoseLogWithUndo(entry),
                  color: theme.colorScheme.error,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Navigate to the edit screen for this dose log entry.
  void _editDoseLog(DoseLogWithTrackable entry) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditDoseScreen(entry: entry)),
    );
  }

  /// Delete a dose and show an "Undo" SnackBar that can re-insert it.
  void _deleteDoseLogWithUndo(DoseLogWithTrackable entry) async {
    final dose = entry.doseLog;
    final db = ref.read(databaseProvider);

    await db.deleteDoseLog(dose.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        showCloseIcon: true,
        // Flutter defaults action snackbars to persist=true.
        // Set persist=false so Undo bars auto-dismiss after a short window.
        persist: false,
        duration: const Duration(seconds: 6),
        content: Text(
          'Deleted ${entry.trackable.name} — ${dose.amount.toStringAsFixed(0)} ${entry.trackable.unit}',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            db.insertDoseLog(
              dose.trackableId,
              dose.amount,
              dose.loggedAt,
              name: dose.name,
              isPlanned: dose.isPlanned,
            );
          },
        ),
      ),
    );
  }

  /// Copy a dose: opens AddDoseScreen pre-filled with this dose's values.
  void _copyDose(DoseLogWithTrackable entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddDoseScreen(
          initialTrackableId: entry.doseLog.trackableId,
          initialAmount: entry.doseLog.amount,
          initialName: entry.doseLog.name,
          initialIsPlanned: entry.doseLog.isPlanned,
        ),
      ),
    );
  }

  /// Navigate to AddDoseScreen, pre-filled to the selected day.
  ///
  /// We pass a calendar date (00:00) instead of the boundary time so the form
  /// opens on the expected date without forcing a strange default hour.
  void _addDose(DateTime selectedBoundary) {
    final selectedCalendarDate = DateTime(
      selectedBoundary.year,
      selectedBoundary.month,
      selectedBoundary.day,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddDoseScreen(initialDate: selectedCalendarDate),
      ),
    );
  }

  /// Formats a day boundary into a readable label.
  /// "Today", "Yesterday", or "Wed, Feb 19, 2026".
  String _formatDayLabel(DateTime boundary, DateTime todayBoundary) {
    if (boundary == todayBoundary) return 'Today';

    final yesterdayBoundary = todayBoundary.subtract(const Duration(days: 1));
    if (boundary == yesterdayBoundary) return 'Yesterday';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[boundary.weekday - 1]}, ${months[boundary.month - 1]} ${boundary.day}, ${boundary.year}';
  }

  /// Format a log's timestamp for display as "HH:MM".
  String _formatLogTime(DateTime loggedAt) {
    final h = loggedAt.hour.toString().padLeft(2, '0');
    final m = loggedAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
