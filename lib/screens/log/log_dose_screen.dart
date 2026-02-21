import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/log/edit_dose_screen.dart';
import 'package:taper/screens/log/widgets/time_picker.dart';

/// LogDoseScreen = the form for recording a substance dose.
///
/// Like a Laravel create form (doses/create.blade.php) with:
///   - A <select> for substance (populated from DB)
///   - An <input type="number"> for amount in mg
///   - A time picker defaulting to "now"
///   - A submit button
///
/// ConsumerStatefulWidget because we need both:
///   - Riverpod providers (ref.watch for substances list, ref.read for DB writes)
///   - Local state (selected substance, amount controller, chosen time)
class LogDoseScreen extends ConsumerStatefulWidget {
  const LogDoseScreen({super.key});

  @override
  ConsumerState<LogDoseScreen> createState() => _LogDoseScreenState();
}

class _LogDoseScreenState extends ConsumerState<LogDoseScreen> {
  // Currently selected substance from the dropdown.
  // null = nothing selected yet. Like: public ?int $substanceId = null;
  Substance? _selectedSubstance;

  // Controller for the amount text field.
  final _amountController = TextEditingController();

  // The chosen time for the dose. Defaults to now, tappable to change.
  // We store both date and time of day separately because Flutter's
  // pickers work with TimeOfDay (just hours/minutes) not full DateTime.
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _resetTime();
  }

  /// Reset the time fields to "right now".
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
    // Watch visible substances only — hidden ones don't appear in the dropdown.
    // The Substances management screen uses substancesProvider (all) instead.
    final substancesAsync = ref.watch(visibleSubstancesProvider);

    return Scaffold(
      body: substancesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (substances) => _buildForm(substances),
      ),
    );
  }

  Widget _buildForm(List<Substance> substances) {
    // If there are no substances, show a hint to create one first.
    if (substances.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No substances yet.\nGo to the Substances tab to add one first.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Auto-select the main substance on first load (when nothing is selected yet).
    // ??= is Dart's null-aware assignment — same as PHP's ??= operator.
    // We set it directly (no setState) because we use it immediately below in
    // the same build pass. The dropdown picks it up via currentSelected.
    // Like setting a default in a Blade form: $selected ??= $substances->firstWhere(...)
    _selectedSubstance ??= substances.where((s) => s.isMain).firstOrNull;

    // Look up the selected substance by ID from the current stream data.
    // Drift's stream emits NEW Substance instances each time, so the old
    // _selectedSubstance object won't match by reference (Dart's == compares
    // all fields). We need the matching instance from the current list for
    // the dropdown's `value` to work correctly.
    // Like: $selected = $substances->firstWhere(fn($s) => $s->id === $selectedId)
    final currentSelected = _selectedSubstance != null
        ? substances.where((s) => s.id == _selectedSubstance!.id).firstOrNull
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Extra top padding to push content below status bar area.
          const SizedBox(height: 40),

          Text(
            'Log Dose',
            style: Theme.of(context).textTheme.headlineMedium,
          ),

          const SizedBox(height: 24),

          // --- Substance picker ---
          // DropdownButtonFormField = <select> in HTML.
          // Populates from the visible substances list (reactive via provider).
          // initialValue sets the dropdown's state on first creation. Since we
          // auto-select _selectedSubstance above (before this widget builds),
          // currentSelected is already set on the first render.
          DropdownButtonFormField<Substance>(
            initialValue: currentSelected,
            decoration: const InputDecoration(
              labelText: 'Substance',
              border: OutlineInputBorder(),
            ),
            // Build one <option> per visible substance.
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
          // number keyboard + decimal support. Like <input type="number" step="0.1">.
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Amount',
              suffixText: 'mg',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // Only allow digits and one decimal point.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
          ),

          const SizedBox(height: 16),

          // --- Time picker ---
          // Tappable row that shows the current date + time.
          // Tapping opens Flutter's built-in date/time picker dialogs.
          // Uses the shared TimePicker widget (like a Blade component: <x-time-picker />).
          TimePicker(
            date: _selectedDate,
            time: _selectedTime,
            onDateChanged: (date) => setState(() => _selectedDate = date),
            onTimeChanged: (time) => setState(() => _selectedTime = time),
          ),

          const SizedBox(height: 24),

          // --- Save button ---
          // ListenableBuilder rebuilds only this button when the amount text changes.
          // Without this, typing in the amount field wouldn't enable/disable the button
          // because TextField changes don't trigger setState on the parent.
          // Same pattern as the SubstanceFormCard's Save button.
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

          const SizedBox(height: 32),

          // --- Recent doses list ---
          // Like showing the last 50 rows from DoseLog::with('substance')->latest()->get()
          // right below the create form — similar to a Livewire table that auto-refreshes.
          //
          // We use ref.watch() so the list reactively updates when doses are
          // added/deleted. The stream provider emits a new list automatically.
          _buildRecentLogs(),
        ],
      ),
    );
  }

  /// Builds the "Recent Doses" section that watches the dose logs stream.
  ///
  /// Uses AsyncValue.when() to handle loading/error/data states — same pattern
  /// as substancesAsync.when() at the top of build().
  ///
  /// Returns widgets directly (not a ListView) because we're already inside a
  /// SingleChildScrollView → Column. Nesting a ListView inside a scroll view
  /// causes layout errors. Instead we .map() the list into ListTiles — like
  /// using @foreach in Blade instead of a separate scrollable <div>.
  Widget _buildRecentLogs() {
    final logsAsync = ref.watch(doseLogsProvider);

    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text('Error loading logs: $error'),
      data: (logs) {
        if (logs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Text(
              'No doses logged yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Doses',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),

            // .map() each log into a ListTile — like @foreach($logs as $log) in Blade.
            // We spread (...) the mapped iterable into the Column's children list.
            ...logs.map((entry) => _buildLogTile(entry)),
          ],
        );
      },
    );
  }

  /// Builds a single log entry card.
  ///
  /// Card.outlined = Material 3's outlined variant — adds a visible border
  /// around each entry. Like wrapping a Blade row in:
  ///   <div class="border rounded-lg p-4">
  ///
  /// onTap navigates to the edit screen — like <a href="/doses/{{ $log->id }}/edit">.
  Widget _buildLogTile(DoseLogWithSubstance entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Card.outlined(
        child: ListTile(
          // "Caffeine — 90 mg"
          title: Text(
            '${entry.substance.name} — ${entry.doseLog.amountMg.toStringAsFixed(0)} mg',
          ),
          // Formatted time with optional date context (see _formatLogTime below).
          subtitle: Text(_formatLogTime(entry.doseLog.loggedAt)),
          // Delete button — same no-confirmation pattern as _deleteSubstance()
          // in substances_screen.dart. Quick corrections for a personal app.
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteDoseLog(entry.doseLog.id),
            tooltip: 'Delete',
          ),
          // Tap the card to navigate to the edit screen.
          // Like clicking a table row in a Livewire component: wire:click="edit({{ $log->id }})".
          onTap: () => _editDoseLog(entry),
        ),
      ),
    );
  }

  /// Navigate to the edit screen for this dose log entry.
  ///
  /// Navigator.push() = like a traditional page navigation (href="/doses/1/edit").
  /// MaterialPageRoute slides the new screen in from the right.
  /// The bottom nav stays underneath, but the edit screen covers it.
  void _editDoseLog(DoseLogWithSubstance entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditDoseScreen(entry: entry),
      ),
    );
  }

  /// Validates that the form is ready to submit.
  /// Like Laravel's $request->validate() check.
  bool _canSave() {
    if (_selectedSubstance == null) return false;
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return false;
    final amount = double.tryParse(amountText);
    return amount != null && amount > 0;
  }

  // Guard against double taps while the async save is in progress.
  bool _saving = false;

  /// Save the dose to the database and reset the form.
  void _saveDose() async {
    if (_saving) return;
    _saving = true;

    final substance = _selectedSubstance!;
    final amount = double.parse(_amountController.text.trim());

    // Combine the separate date and time into a single DateTime.
    // Flutter's time picker gives TimeOfDay (hours+minutes only),
    // so we merge it with the selected date.
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

    // Reset form: keep substance selected (convenient for repeat logging),
    // clear amount, reset time to now.
    _amountController.clear();
    _resetTime();
    _saving = false;
    setState(() {});
  }

  /// Delete a dose log by ID. No confirmation — matches the quick-delete
  /// pattern from _deleteSubstance() in substances_screen.dart.
  /// The stream provider automatically re-emits the updated list.
  void _deleteDoseLog(int id) async {
    await ref.read(databaseProvider).deleteDoseLog(id);
  }

  /// Format a log's timestamp for display in the recent logs list.
  ///
  /// Shows just the time for today's entries (e.g., "2:45 PM"),
  /// and adds date context for older ones (e.g., "Fri, Feb 20 — 2:45 PM").
  /// Like Carbon's diffForHumans() but with a fixed format.
  String _formatLogTime(DateTime loggedAt) {
    final now = DateTime.now();
    final time = TimeOfDay.fromDateTime(loggedAt).format(context);

    // Same calendar day? Just show the time.
    final isToday = loggedAt.year == now.year &&
        loggedAt.month == now.month &&
        loggedAt.day == now.day;

    if (isToday) return time;

    // Yesterday check — compare calendar days, not 24h windows.
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final isYesterday = loggedAt.year == yesterday.year &&
        loggedAt.month == yesterday.month &&
        loggedAt.day == yesterday.day;

    if (isYesterday) return 'Yesterday, $time';

    // Older: show short date + time using the same format as _TimePicker._formatDate().
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dateStr = '${days[loggedAt.weekday - 1]}, ${months[loggedAt.month - 1]} ${loggedAt.day}';
    return '$dateStr — $time';
  }
}

