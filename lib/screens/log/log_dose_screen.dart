import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/log/add_dose_screen.dart';
import 'package:taper/screens/log/edit_dose_screen.dart';

/// LogDoseScreen = the "Log" tab showing recent doses with a FAB to add new ones.
///
/// The FAB navigates to a dedicated AddDoseScreen for the full form.
/// The quick-add dialog (from dashboard cards) still exists for rapid logging.
///
/// Like a Laravel index page (doses/index.blade.php) with a "Create" button
/// that navigates to a separate create page.
///
/// ConsumerStatefulWidget because we need both:
///   - Riverpod providers (ref.watch for recent logs, ref.read for DB writes)
///   - Local state (none currently, but ConsumerStateful for FAB callbacks)
class LogDoseScreen extends ConsumerStatefulWidget {
  const LogDoseScreen({super.key});

  @override
  ConsumerState<LogDoseScreen> createState() => _LogDoseScreenState();
}

class _LogDoseScreenState extends ConsumerState<LogDoseScreen> {
  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(doseLogsProvider);

    return Scaffold(
      // FAB navigates to the add dose screen.
      // heroTag must be unique across all visible FABs to avoid hero animation
      // conflicts. Multiple tabs can be in the widget tree at once, so each
      // FAB needs its own tag (like unique element IDs in HTML).
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
          data: (logs) => _buildLogsList(logs),
        ),
      ),
    );
  }

  Widget _buildLogsList(List<DoseLogWithTrackable> logs) {
    if (logs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Log',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
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

    // +1 for the header.
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length + 1,
      itemBuilder: (context, index) {
        // First item = "Log" heading.
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Log',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          );
        }

        return _buildLogTile(logs[index - 1]);
      },
    );
  }

  /// Builds a single log entry card wrapped in Dismissible for swipe-to-delete.
  ///
  /// Dismissible = Flutter's swipe-to-dismiss widget, like a swipe handler in
  /// a mobile list. Swiping left reveals a red background with a trash icon,
  /// then deletes the dose and shows an "Undo" SnackBar.
  Widget _buildLogTile(DoseLogWithTrackable entry) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Dismissible(
        key: ValueKey(entry.doseLog.id),
        direction: DismissDirection.endToStart,
        background: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: theme.colorScheme.errorContainer,
            child: Icon(
              Icons.delete_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ),
        onDismissed: (_) => _deleteDoseLogWithUndo(entry),
        child: Card(
          shape: shape,
          clipBehavior: Clip.antiAlias, // clips ink to rounded corners
          child: InkWell(
            customBorder: shape,
            onTap: () => _editDoseLog(entry),
            child: ListTile(
              title: Text(
                '${entry.trackable.name} — ${entry.doseLog.amount.toStringAsFixed(0)} ${entry.trackable.unit}',
              ),
              subtitle: Text(_formatLogTime(entry.doseLog.loggedAt)),
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
  ///
  /// Stores the dose details before deleting so we can re-insert on undo.
  /// Like a soft-delete with immediate restore — the SnackBar acts as a
  /// brief "trash" window before the delete becomes permanent.
  void _deleteDoseLogWithUndo(DoseLogWithTrackable entry) async {
    final dose = entry.doseLog;
    final db = ref.read(databaseProvider);

    // Delete the dose from the database.
    await db.deleteDoseLog(dose.id);

    // Guard against the widget being disposed (e.g., user navigated away)
    // before the SnackBar can be shown. Like checking $this->component in Livewire.
    if (!mounted) return;

    // Show SnackBar with "Undo" action. ScaffoldMessenger is the global SnackBar
    // controller — like a toast notification manager.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deleted ${entry.trackable.name} — ${dose.amount.toStringAsFixed(0)} ${entry.trackable.unit}',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // Re-insert with the same trackable, amount, and timestamp.
            // This creates a new row (new ID) but with identical data.
            db.insertDoseLog(dose.trackableId, dose.amount, dose.loggedAt);
          },
        ),
      ),
    );
  }

  /// Navigate to the add dose screen.
  /// Like clicking "Create" in a Laravel resource → GET /doses/create.
  void _addDose() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddDoseScreen()),
    );
  }

  /// Format a log's timestamp for display in the recent logs list.
  /// Uses 24h NATO format.
  String _formatLogTime(DateTime loggedAt) {
    final now = DateTime.now();
    final h = loggedAt.hour.toString().padLeft(2, '0');
    final m = loggedAt.minute.toString().padLeft(2, '0');
    final time = '$h:$m';

    final isToday = loggedAt.year == now.year &&
        loggedAt.month == now.month &&
        loggedAt.day == now.day;
    if (isToday) return time;

    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final isYesterday = loggedAt.year == yesterday.year &&
        loggedAt.month == yesterday.month &&
        loggedAt.day == yesterday.day;
    if (isYesterday) return 'Yesterday, $time';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dateStr = '${days[loggedAt.weekday - 1]}, ${months[loggedAt.month - 1]} ${loggedAt.day}';
    return '$dateStr — $time';
  }
}
