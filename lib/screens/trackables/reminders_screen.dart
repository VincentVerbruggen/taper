import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/data/reminder_type.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/services/reminder_scheduler.dart';

/// Dedicated screen for managing reminders for a trackable.
///
/// Shows a list of reminders with enable/disable toggles and delete buttons.
/// Tapping a reminder opens an edit dialog; FAB opens an add dialog.
///
/// Two reminder types supported:
///   - Scheduled: fire at a specific time (daily or one-time), with optional nag
///   - Logging Gap: fire when no dose logged within a daily window
///
/// Like a Laravel resource controller for reminders:
///   Route::resource('trackables/{trackable}/reminders', ReminderController::class)
class RemindersScreen extends ConsumerWidget {
  /// The trackable whose reminders we're managing.
  final Trackable trackable;

  const RemindersScreen({super.key, required this.trackable});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider(trackable.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'remindersFab',
        onPressed: () => _showAddReminderDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error loading reminders: $e')),
        data: (remindersList) {
          if (remindersList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No reminders yet.\nTap + to add one.',
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
            itemCount: remindersList.length,
            itemBuilder: (context, index) {
              final reminder = remindersList[index];
              return _buildReminderCard(context, ref, reminder);
            },
          );
        },
      ),
    );
  }

  /// Builds a card for a single reminder with title, schedule info,
  /// enable/disable switch, and delete button.
  Widget _buildReminderCard(
    BuildContext context,
    WidgetRef ref,
    Reminder reminder,
  ) {
    final type = ReminderType.fromString(reminder.type);
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
          onTap: () => _showEditReminderDialog(context, ref, reminder),
          child: ListTile(
            title: Text(reminder.label),
            subtitle: Text(_formatReminderInfo(reminder, type)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Enable/disable toggle — schedules or cancels the reminder.
                Switch(
                  value: reminder.isEnabled,
                  onChanged: (enabled) async {
                    final db = ref.read(databaseProvider);
                    await db.updateReminder(
                      reminder.id,
                      isEnabled: Value(enabled),
                    );
                    if (enabled) {
                      await ReminderScheduler.instance.scheduleReminder(
                        // Re-read the reminder to get the updated isEnabled flag.
                        Reminder(
                          id: reminder.id,
                          trackableId: reminder.trackableId,
                          type: reminder.type,
                          label: reminder.label,
                          isEnabled: true,
                          scheduledTime: reminder.scheduledTime,
                          isRecurring: reminder.isRecurring,
                          oneTimeDate: reminder.oneTimeDate,
                          nagEnabled: reminder.nagEnabled,
                          nagIntervalMinutes: reminder.nagIntervalMinutes,
                          windowStart: reminder.windowStart,
                          windowEnd: reminder.windowEnd,
                          gapMinutes: reminder.gapMinutes,
                        ),
                        trackable,
                      );
                    } else {
                      await ReminderScheduler.instance
                          .cancelReminder(reminder.id);
                    }
                  },
                ),
                // Delete button.
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () async {
                    await ReminderScheduler.instance
                        .cancelReminder(reminder.id);
                    ref.read(databaseProvider).deleteReminder(reminder.id);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Formats a reminder's schedule info for the card subtitle.
  ///
  /// Scheduled: "Daily at 8:00 AM" or "Feb 22 at 8:00 AM" + " · Nag every 15 min"
  /// Gap: "7:00 AM – 3:30 PM · Nudge after 2h"
  String _formatReminderInfo(Reminder reminder, ReminderType type) {
    if (type == ReminderType.scheduled) {
      final time = reminder.scheduledTime ?? '--:--';
      final timeStr = _formatTimeStr(time);
      String info;
      if (reminder.isRecurring) {
        info = 'Daily at $timeStr';
      } else if (reminder.oneTimeDate != null) {
        final d = reminder.oneTimeDate!;
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
        info = '${months[d.month - 1]} ${d.day} at $timeStr';
      } else {
        info = 'At $timeStr';
      }
      if (reminder.nagEnabled && reminder.nagIntervalMinutes != null) {
        info += ' · Nag every ${reminder.nagIntervalMinutes} min';
      }
      return info;
    } else {
      // Logging gap.
      final start = _formatTimeStr(reminder.windowStart ?? '--:--');
      final end = _formatTimeStr(reminder.windowEnd ?? '--:--');
      final gap = reminder.gapMinutes ?? 0;
      // Format gap as hours + minutes for readability.
      final gapStr = gap >= 60
          ? '${gap ~/ 60}h${gap % 60 > 0 ? ' ${gap % 60}m' : ''}'
          : '${gap}m';
      return '$start – $end · Nudge after $gapStr';
    }
  }

  /// Formats "HH:MM" (24h) into a more readable format.
  /// Keeps 24h format for consistency with the rest of the app.
  String _formatTimeStr(String hhmm) {
    return hhmm;
  }

  /// Shows the add reminder dialog with a type selector and conditional fields.
  void _showAddReminderDialog(BuildContext context, WidgetRef ref) {
    // Initial state for the dialog form.
    var selectedType = ReminderType.scheduled;
    final labelController = TextEditingController();
    var scheduledTime = const TimeOfDay(hour: 8, minute: 0);
    var isRecurring = true;
    var oneTimeDate = DateTime.now().add(const Duration(days: 1));
    var nagEnabled = false;
    final nagIntervalController = TextEditingController(text: '15');
    var windowStartTime = const TimeOfDay(hour: 7, minute: 0);
    var windowEndTime = const TimeOfDay(hour: 15, minute: 0);
    final gapMinutesController = TextEditingController(text: '120');
    var submitted = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Validation: check required fields based on type.
            final labelError = submitted && labelController.text.trim().isEmpty
                ? 'Required'
                : null;
            final nagError = selectedType == ReminderType.scheduled && nagEnabled
                ? _intFieldError(nagIntervalController.text, submitted: submitted)
                : null;
            final gapError = selectedType == ReminderType.loggingGap
                ? _intFieldError(gapMinutesController.text, submitted: submitted)
                : null;

            return AlertDialog(
              title: const Text('Add Reminder'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Type selector ---
                    // Dropdown for choosing between Scheduled and Logging Gap.
                    // Full width to match the other form fields (OutlineInputBorder).
                    DropdownButtonFormField<ReminderType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: ReminderType.values.map((type) {
                        return DropdownMenuItem<ReminderType>(
                          value: type,
                          child: Text(type.displayName),
                        );
                      }).toList(),
                      onChanged: (type) {
                        if (type != null) {
                          setDialogState(() => selectedType = type);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    // Brief description of what this type does.
                    // Helps users pick the right one without trial and error.
                    Text(
                      selectedType == ReminderType.scheduled
                          ? 'Fires at a specific time each day (or once). Can nag repeatedly until you log a dose.'
                          : 'Fires when you haven\'t logged a dose within a time window. Resets each time you log.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Label ---
                    TextField(
                      controller: labelController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Label',
                        hintText: selectedType == ReminderType.scheduled
                            ? 'e.g. Morning dose'
                            : 'e.g. Coffee check',
                        border: const OutlineInputBorder(),
                        errorText: labelError,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // --- Conditional fields based on type ---
                    if (selectedType == ReminderType.scheduled) ...[
                      // Time picker button.
                      _buildTimePickerTile(
                        context: context,
                        label: 'Time',
                        time: scheduledTime,
                        onChanged: (t) => setDialogState(() => scheduledTime = t),
                      ),
                      const SizedBox(height: 8),

                      // Repeat daily switch.
                      SwitchListTile(
                        title: const Text('Repeat daily'),
                        value: isRecurring,
                        onChanged: (v) => setDialogState(() => isRecurring = v),
                        dense: true,
                      ),

                      // Date picker (only for one-time).
                      if (!isRecurring) ...[
                        const SizedBox(height: 8),
                        _buildDatePickerTile(
                          context: context,
                          label: 'Date',
                          date: oneTimeDate,
                          onChanged: (d) => setDialogState(() => oneTimeDate = d),
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Nag until logged switch.
                      SwitchListTile(
                        title: const Text('Nag until logged'),
                        value: nagEnabled,
                        onChanged: (v) => setDialogState(() => nagEnabled = v),
                        dense: true,
                      ),

                      // Nag interval (only when nag enabled).
                      if (nagEnabled) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: nagIntervalController,
                          decoration: InputDecoration(
                            labelText: 'Nag interval (minutes)',
                            border: const OutlineInputBorder(),
                            errorText: nagError,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ],
                    ],

                    if (selectedType == ReminderType.loggingGap) ...[
                      // Window start time.
                      _buildTimePickerTile(
                        context: context,
                        label: 'Window start',
                        time: windowStartTime,
                        onChanged: (t) =>
                            setDialogState(() => windowStartTime = t),
                      ),
                      const SizedBox(height: 8),
                      // Window end time.
                      _buildTimePickerTile(
                        context: context,
                        label: 'Window end',
                        time: windowEndTime,
                        onChanged: (t) =>
                            setDialogState(() => windowEndTime = t),
                      ),
                      const SizedBox(height: 16),
                      // Gap threshold.
                      TextField(
                        controller: gapMinutesController,
                        decoration: InputDecoration(
                          labelText: 'Gap threshold (minutes)',
                          border: const OutlineInputBorder(),
                          errorText: gapError,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final label = labelController.text.trim();
                    // Validate based on type.
                    bool valid = label.isNotEmpty;
                    if (selectedType == ReminderType.scheduled && nagEnabled) {
                      valid = valid &&
                          int.tryParse(nagIntervalController.text.trim()) != null &&
                          int.parse(nagIntervalController.text.trim()) > 0;
                    }
                    if (selectedType == ReminderType.loggingGap) {
                      valid = valid &&
                          int.tryParse(gapMinutesController.text.trim()) != null &&
                          int.parse(gapMinutesController.text.trim()) > 0;
                    }

                    if (!valid) {
                      submitted = true;
                      setDialogState(() {});
                      return;
                    }

                    final db = ref.read(databaseProvider);
                    final reminderId = await db.insertReminder(
                      trackableId: trackable.id,
                      type: selectedType.toDbString(),
                      label: label,
                      scheduledTime: selectedType == ReminderType.scheduled
                          ? _timeOfDayToString(scheduledTime)
                          : null,
                      isRecurring: isRecurring,
                      oneTimeDate: !isRecurring ? oneTimeDate : null,
                      nagEnabled: nagEnabled,
                      nagIntervalMinutes: nagEnabled
                          ? int.tryParse(nagIntervalController.text.trim())
                          : null,
                      windowStart: selectedType == ReminderType.loggingGap
                          ? _timeOfDayToString(windowStartTime)
                          : null,
                      windowEnd: selectedType == ReminderType.loggingGap
                          ? _timeOfDayToString(windowEndTime)
                          : null,
                      gapMinutes: selectedType == ReminderType.loggingGap
                          ? int.tryParse(gapMinutesController.text.trim())
                          : null,
                    );

                    // Schedule the notification for the newly created reminder.
                    final allReminders = await db.getReminders(trackable.id);
                    final newReminder = allReminders
                        .where((r) => r.id == reminderId)
                        .firstOrNull;
                    if (newReminder != null) {
                      await ReminderScheduler.instance.scheduleReminder(
                        newReminder,
                        trackable,
                      );
                    }

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
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

  /// Shows the edit reminder dialog, pre-filled with existing values.
  void _showEditReminderDialog(
    BuildContext context,
    WidgetRef ref,
    Reminder reminder,
  ) {
    var selectedType = ReminderType.fromString(reminder.type);
    final labelController = TextEditingController(text: reminder.label);

    // Parse existing scheduled time.
    TimeOfDay scheduledTime;
    if (reminder.scheduledTime != null) {
      final parts = reminder.scheduledTime!.split(':');
      scheduledTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 8,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      );
    } else {
      scheduledTime = const TimeOfDay(hour: 8, minute: 0);
    }

    var isRecurring = reminder.isRecurring;
    var oneTimeDate = reminder.oneTimeDate ?? DateTime.now().add(const Duration(days: 1));
    var nagEnabled = reminder.nagEnabled;
    final nagIntervalController = TextEditingController(
      text: reminder.nagIntervalMinutes?.toString() ?? '15',
    );

    // Parse existing window times.
    TimeOfDay windowStartTime;
    if (reminder.windowStart != null) {
      final parts = reminder.windowStart!.split(':');
      windowStartTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 7,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      );
    } else {
      windowStartTime = const TimeOfDay(hour: 7, minute: 0);
    }

    TimeOfDay windowEndTime;
    if (reminder.windowEnd != null) {
      final parts = reminder.windowEnd!.split(':');
      windowEndTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 15,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      );
    } else {
      windowEndTime = const TimeOfDay(hour: 15, minute: 0);
    }

    final gapMinutesController = TextEditingController(
      text: reminder.gapMinutes?.toString() ?? '120',
    );
    var submitted = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final labelError = submitted && labelController.text.trim().isEmpty
                ? 'Required'
                : null;
            final nagError = selectedType == ReminderType.scheduled && nagEnabled
                ? _intFieldError(nagIntervalController.text, submitted: submitted)
                : null;
            final gapError = selectedType == ReminderType.loggingGap
                ? _intFieldError(gapMinutesController.text, submitted: submitted)
                : null;

            return AlertDialog(
              title: const Text('Edit Reminder'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Type selector (can change type on edit).
                    DropdownButtonFormField<ReminderType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: ReminderType.values.map((type) {
                        return DropdownMenuItem<ReminderType>(
                          value: type,
                          child: Text(type.displayName),
                        );
                      }).toList(),
                      onChanged: (type) {
                        if (type != null) {
                          setDialogState(() => selectedType = type);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedType == ReminderType.scheduled
                          ? 'Fires at a specific time each day (or once). Can nag repeatedly until you log a dose.'
                          : 'Fires when you haven\'t logged a dose within a time window. Resets each time you log.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: labelController,
                      decoration: InputDecoration(
                        labelText: 'Label',
                        border: const OutlineInputBorder(),
                        errorText: labelError,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),

                    if (selectedType == ReminderType.scheduled) ...[
                      _buildTimePickerTile(
                        context: context,
                        label: 'Time',
                        time: scheduledTime,
                        onChanged: (t) => setDialogState(() => scheduledTime = t),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Repeat daily'),
                        value: isRecurring,
                        onChanged: (v) => setDialogState(() => isRecurring = v),
                        dense: true,
                      ),
                      if (!isRecurring) ...[
                        const SizedBox(height: 8),
                        _buildDatePickerTile(
                          context: context,
                          label: 'Date',
                          date: oneTimeDate,
                          onChanged: (d) => setDialogState(() => oneTimeDate = d),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Nag until logged'),
                        value: nagEnabled,
                        onChanged: (v) => setDialogState(() => nagEnabled = v),
                        dense: true,
                      ),
                      if (nagEnabled) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: nagIntervalController,
                          decoration: InputDecoration(
                            labelText: 'Nag interval (minutes)',
                            border: const OutlineInputBorder(),
                            errorText: nagError,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ],
                    ],

                    if (selectedType == ReminderType.loggingGap) ...[
                      _buildTimePickerTile(
                        context: context,
                        label: 'Window start',
                        time: windowStartTime,
                        onChanged: (t) =>
                            setDialogState(() => windowStartTime = t),
                      ),
                      const SizedBox(height: 8),
                      _buildTimePickerTile(
                        context: context,
                        label: 'Window end',
                        time: windowEndTime,
                        onChanged: (t) =>
                            setDialogState(() => windowEndTime = t),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: gapMinutesController,
                        decoration: InputDecoration(
                          labelText: 'Gap threshold (minutes)',
                          border: const OutlineInputBorder(),
                          errorText: gapError,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final label = labelController.text.trim();
                    bool valid = label.isNotEmpty;
                    if (selectedType == ReminderType.scheduled && nagEnabled) {
                      valid = valid &&
                          int.tryParse(nagIntervalController.text.trim()) != null &&
                          int.parse(nagIntervalController.text.trim()) > 0;
                    }
                    if (selectedType == ReminderType.loggingGap) {
                      valid = valid &&
                          int.tryParse(gapMinutesController.text.trim()) != null &&
                          int.parse(gapMinutesController.text.trim()) > 0;
                    }

                    if (!valid) {
                      submitted = true;
                      setDialogState(() {});
                      return;
                    }

                    final db = ref.read(databaseProvider);

                    // Cancel old notifications before updating.
                    await ReminderScheduler.instance.cancelReminder(reminder.id);

                    // Update using raw SQL companion since we need to set
                    // many fields at once, including clearing irrelevant ones.
                    await db.updateReminder(
                      reminder.id,
                      label: label,
                      scheduledTime: selectedType == ReminderType.scheduled
                          ? Value(_timeOfDayToString(scheduledTime))
                          : const Value(null),
                      isRecurring: Value(isRecurring),
                      oneTimeDate: !isRecurring
                          ? Value(oneTimeDate)
                          : const Value(null),
                      nagEnabled: Value(nagEnabled),
                      nagIntervalMinutes: nagEnabled
                          ? Value(int.tryParse(nagIntervalController.text.trim()))
                          : const Value(null),
                      windowStart: selectedType == ReminderType.loggingGap
                          ? Value(_timeOfDayToString(windowStartTime))
                          : const Value(null),
                      windowEnd: selectedType == ReminderType.loggingGap
                          ? Value(_timeOfDayToString(windowEndTime))
                          : const Value(null),
                      gapMinutes: selectedType == ReminderType.loggingGap
                          ? Value(int.tryParse(gapMinutesController.text.trim()))
                          : const Value(null),
                    );

                    // We also need to update the type field directly since
                    // updateReminder() doesn't handle it. Use raw update.
                    await (db.update(db.reminders)
                          ..where((t) => t.id.equals(reminder.id)))
                        .write(RemindersCompanion(
                          type: Value(selectedType.toDbString()),
                        ));

                    // Reschedule with updated values.
                    final updated = await db.getReminders(trackable.id);
                    final updatedReminder = updated
                        .where((r) => r.id == reminder.id)
                        .firstOrNull;
                    if (updatedReminder != null) {
                      await ReminderScheduler.instance.scheduleReminder(
                        updatedReminder,
                        trackable,
                      );
                    }

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
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

  /// Builds a time picker tile: label on the left, selected time on the right.
  /// Tapping opens the Material time picker dialog.
  Widget _buildTimePickerTile({
    required BuildContext context,
    required String label,
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onChanged,
  }) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$h:$m'),
            const Icon(Icons.access_time, size: 20),
          ],
        ),
      ),
    );
  }

  /// Builds a date picker tile: label on the left, selected date on the right.
  Widget _buildDatePickerTile({
    required BuildContext context,
    required String label,
    required DateTime date,
    required ValueChanged<DateTime> onChanged,
  }) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${months[date.month - 1]} ${date.day}, ${date.year}'),
            const Icon(Icons.calendar_today, size: 20),
          ],
        ),
      ),
    );
  }

  /// Convert a TimeOfDay to "HH:MM" string for database storage.
  String _timeOfDayToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Validate a positive integer field.
  /// Returns error string or null if valid.
  String? _intFieldError(String text, {bool submitted = false}) {
    if (text.trim().isEmpty) {
      return submitted ? 'Required' : null;
    }
    final value = int.tryParse(text.trim());
    if (value == null) return 'Enter a valid number';
    if (value <= 0) return 'Must be greater than zero';
    return null;
  }
}
