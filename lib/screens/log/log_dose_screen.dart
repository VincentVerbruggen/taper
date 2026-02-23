import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/log/add_dose_screen.dart';
import 'package:taper/screens/log/edit_dose_screen.dart';
import 'package:taper/utils/day_boundary.dart';

/// LogDoseScreen = the "Log" tab showing recent doses grouped by day,
/// with a FAB to add new ones and a calendar button to jump to a date.
///
/// Doses are grouped by the configurable day boundary (default 5 AM).
/// Each group has a small date header ("Today", "Yesterday", "Wed, Feb 19").
///
/// Like a Laravel index page with groupBy:
///   DoseLog::with('trackable')->latest()->limit(50)->get()
///       ->groupBy(fn($d) => dayBoundary($d->logged_at)->format('Y-m-d'))
class LogDoseScreen extends ConsumerStatefulWidget {
  const LogDoseScreen({super.key});

  @override
  ConsumerState<LogDoseScreen> createState() => _LogDoseScreenState();
}

class _LogDoseScreenState extends ConsumerState<LogDoseScreen> {
  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(doseLogsProvider);
    final boundaryHour = ref.watch(dayBoundaryHourProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'logDoseFab',
        onPressed: () => _addDose(),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: false,
        child: logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (logs) => _buildLogsList(logs, boundaryHour),
        ),
      ),
    );
  }

  Widget _buildLogsList(List<DoseLogWithTrackable> logs, int boundaryHour) {
    if (logs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header row with title and calendar button.
          _buildHeaderRow(),
          const SizedBox(height: 48),
          Text(
            'No doses logged yet.\nTap + to log your first dose.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // Group logs by day boundary.
    // LinkedHashMap preserves insertion order → most recent day first.
    final grouped = <DateTime, List<DoseLogWithTrackable>>{};
    for (final entry in logs) {
      final boundary = dayBoundary(entry.doseLog.loggedAt, boundaryHour: boundaryHour);
      grouped.putIfAbsent(boundary, () => []).add(entry);
    }

    // Build a flat list of items: header row, then for each day group:
    // day header + dose entries.
    final items = <Widget>[];
    items.add(_buildHeaderRow());

    final now = DateTime.now();
    final todayBoundary = dayBoundary(now, boundaryHour: boundaryHour);

    for (final entry in grouped.entries) {
      final dayLabel = _formatDayLabel(entry.key, todayBoundary);
      items.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(
            dayLabel,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      for (final log in entry.value) {
        items.add(_buildLogTile(log));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: items,
    );
  }

  /// Header row with "Log" title and calendar button.
  /// Matches the pattern of Dashboard (title + action icon in a Row).
  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Log',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        IconButton(
          icon: const Icon(Icons.calendar_today),
          tooltip: 'Jump to date',
          onPressed: _showDatePicker,
        ),
      ],
    );
  }

  /// Opens a date picker and navigates to AddDoseScreen pre-set to that date.
  /// Lets users log a dose for a specific past date without having to
  /// manually adjust the time picker in the form.
  void _showDatePicker() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (picked != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddDoseScreen(
            initialDate: picked,
          ),
        ),
      );
    }
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
                          ),            // Show just the time (HH:MM) since the day header already
            // provides the date context.
            subtitle: Text(_formatLogTime(entry.doseLog.loggedAt)),
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
      MaterialPageRoute(
        builder: (_) => EditDoseScreen(entry: entry),
      ),
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
        content: Text(
          'Deleted ${entry.trackable.name} — ${dose.amount.toStringAsFixed(0)} ${entry.trackable.unit}',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            db.insertDoseLog(dose.trackableId, dose.amount, dose.loggedAt, name: dose.name);
          },
        ),
      ),
    );
  }

  /// Copy a dose: opens AddDoseScreen pre-filled with this dose's trackable + amount.
  void _copyDose(DoseLogWithTrackable entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddDoseScreen(
          initialTrackableId: entry.doseLog.trackableId,
          initialAmount: entry.doseLog.amount,
          initialName: entry.doseLog.name,
        ),
      ),
    );
  }

  /// Navigate to the add dose screen.
  void _addDose() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddDoseScreen()),
    );
  }

  /// Formats a day boundary into a readable label.
  /// "Today", "Yesterday", or "Wed, Feb 19".
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

  /// Format a log's timestamp for display. Shows just time for today,
  /// includes day info for older entries.
  String _formatLogTime(DateTime loggedAt) {
    final h = loggedAt.hour.toString().padLeft(2, '0');
    final m = loggedAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
