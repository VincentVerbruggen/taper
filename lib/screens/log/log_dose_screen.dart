import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/log/edit_dose_screen.dart';
import 'package:taper/screens/log/widgets/time_picker.dart';

/// LogDoseScreen = the "Log" tab showing recent doses with a FAB to add new ones.
///
/// The form for logging a dose is now behind the FAB (bottom sheet), so the
/// main screen is just the recent logs list with a "Log" heading.
///
/// Like a Laravel index page (doses/index.blade.php) with a "Create" button
/// that opens a modal instead of navigating to a separate create page.
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
      // FAB opens the log dose bottom sheet — the full form with substance
      // picker, amount, and time.
      // heroTag must be unique across all visible FABs to avoid hero animation
      // conflicts. Multiple tabs can be in the widget tree at once, so each
      // FAB needs its own tag (like unique element IDs in HTML).
      floatingActionButton: FloatingActionButton(
        heroTag: 'logDoseFab',
        onPressed: () => _showLogDoseSheet(context),
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

  Widget _buildLogsList(List<DoseLogWithSubstance> logs) {
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

  /// Builds a single log entry card.
  Widget _buildLogTile(DoseLogWithSubstance entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Card.outlined(
        child: ListTile(
          // "Caffeine — 90 mg" or "Water — 500 ml".
          title: Text(
            '${entry.substance.name} — ${entry.doseLog.amount.toStringAsFixed(0)} ${entry.substance.unit}',
          ),
          subtitle: Text(_formatLogTime(entry.doseLog.loggedAt)),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteDoseLog(entry.doseLog.id),
            tooltip: 'Delete',
          ),
          onTap: () => _editDoseLog(entry),
        ),
      ),
    );
  }

  /// Navigate to the edit screen for this dose log entry.
  void _editDoseLog(DoseLogWithSubstance entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditDoseScreen(entry: entry),
      ),
    );
  }

  void _deleteDoseLog(int id) async {
    await ref.read(databaseProvider).deleteDoseLog(id);
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

  /// Opens a bottom sheet with the full log dose form: substance picker,
  /// amount, time, and a save button. Like a modal create form.
  void _showLogDoseSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // useSafeArea prevents the sheet from going under the status bar.
      useSafeArea: true,
      builder: (sheetContext) {
        // The bottom sheet is a ConsumerStatefulWidget, so it has its own
        // ref and can watch providers directly. Riverpod scopes flow through
        // the widget tree, so the sheet inherits the same ProviderScope.
        return const _LogDoseBottomSheet();
      },
    );
  }
}

/// The log dose form shown in a bottom sheet.
///
/// Contains the full form: substance picker, amount, time, save button.
/// Like the old inline form, but in a modal that slides up from the bottom.
///
/// ConsumerStatefulWidget because it needs to:
///   - Watch providers (visibleSubstancesProvider) to load substances
///   - Read providers (databaseProvider) to save doses
///   - Manage local form state (controllers, selected time)
///
/// IMPORTANT: Must be a ConsumerStatefulWidget (not plain StatefulWidget
/// with parentRef) so `ref.watch()` properly triggers rebuilds when async
/// data arrives. A plain StatefulWidget calling parentRef.watch() won't
/// rebuild itself — only the parent Consumer rebuilds.
class _LogDoseBottomSheet extends ConsumerStatefulWidget {
  const _LogDoseBottomSheet();

  @override
  ConsumerState<_LogDoseBottomSheet> createState() => _LogDoseBottomSheetState();
}

class _LogDoseBottomSheetState extends ConsumerState<_LogDoseBottomSheet> {
  Substance? _selectedSubstance;
  final _amountController = TextEditingController();
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _resetTime();
  }

  void _resetTime() {
    final now = DateTime.now();
    _selectedDate = now;
    _selectedTime = TimeOfDay.fromDateTime(now);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch visible substances — triggers rebuild when data arrives.
    final substancesAsync = ref.watch(visibleSubstancesProvider);

    return substancesAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => SizedBox(height: 200, child: Center(child: Text('Error: $e'))),
      data: (substances) => _buildForm(substances),
    );
  }

  Widget _buildForm(List<Substance> substances) {
    if (substances.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No substances. Add one first.')),
      );
    }

    // Auto-select the main substance on first load.
    _selectedSubstance ??= substances.where((s) => s.isMain).firstOrNull;

    // Look up the selected substance from the current stream data.
    final currentSelected = _selectedSubstance != null
        ? substances.where((s) => s.id == _selectedSubstance!.id).firstOrNull
        : null;

    // Padding.fromViewPadding adds space for the keyboard so fields stay visible.
    // Like adding padding-bottom for a virtual keyboard in CSS.
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Log Dose',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),

          // --- Substance picker ---
          DropdownButtonFormField<Substance>(
            initialValue: currentSelected,
            decoration: const InputDecoration(
              labelText: 'Substance',
              border: OutlineInputBorder(),
            ),
            items: substances.map((s) {
              return DropdownMenuItem<Substance>(
                value: s,
                child: Text(s.name),
              );
            }).toList(),
            onChanged: (substance) {
              setState(() => _selectedSubstance = substance);
            },
          ),

          const SizedBox(height: 16),

          // --- Amount input ---
          TextField(
            controller: _amountController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Amount',
              suffixText: _selectedSubstance?.unit ?? 'mg',
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
          ),

          const SizedBox(height: 16),

          // --- Time picker ---
          TimePicker(
            date: _selectedDate,
            time: _selectedTime,
            onDateChanged: (date) => setState(() => _selectedDate = date),
            onTimeChanged: (time) => setState(() => _selectedTime = time),
          ),

          const SizedBox(height: 20),

          // --- Save button ---
          ListenableBuilder(
            listenable: _amountController,
            builder: (context, child) {
              return FilledButton.icon(
                onPressed: _canSave() ? _saveDose : null,
                icon: const Icon(Icons.check),
                label: const Text('Log Dose'),
              );
            },
          ),
        ],
      ),
    );
  }

  bool _canSave() {
    if (_selectedSubstance == null) return false;
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return false;
    final amount = double.tryParse(amountText);
    return amount != null && amount > 0;
  }

  bool _saving = false;

  void _saveDose() async {
    if (_saving) return;
    _saving = true;

    final substance = _selectedSubstance!;
    final amount = double.parse(_amountController.text.trim());
    final loggedAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    await ref.read(databaseProvider).insertDoseLog(
      substance.id,
      amount,
      loggedAt,
    );

    _saving = false;
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
