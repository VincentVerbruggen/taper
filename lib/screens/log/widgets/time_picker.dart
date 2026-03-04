import 'package:flutter/material.dart';
import 'package:wheel_picker/wheel_picker.dart';

/// Tappable date + time display that opens picker dialogs.
///
/// Like two <input type="date"> and <input type="time"> side by side,
/// but using Flutter's native Material 3 picker dialogs.
///
/// Extracted into its own file so both LogDoseScreen (create) and
/// EditDoseScreen (edit) can reuse it — like a Blade component:
///   `<x-time-picker :date="$date" :time="$time" />`
class TimePicker extends StatelessWidget {
  final DateTime date;
  final TimeOfDay time;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TimeOfDay> onTimeChanged;

  const TimePicker({
    super.key,
    required this.date,
    required this.time,
    required this.onDateChanged,
    required this.onTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Date chip — tap to open date picker
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickDate(context),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(formatDate(date)),
          ),
        ),

        const SizedBox(width: 12),

        // Time chip — tap to open time picker.
        // Shows 24h NATO format: "14:30" instead of locale-dependent AM/PM.
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickTime(context),
            icon: const Icon(Icons.access_time, size: 18),
            label: Text(format24h(time)),
          ),
        ),
      ],
    );
  }

  void _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      // Allow logging as far back as needed (no artificial 7-day limit).
      // Users may need to backfill old data or correct entries from weeks ago.
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) onDateChanged(picked);
  }

  void _pickTime(BuildContext context) async {
    // Experimental wheel-based time input:
    // Keep date selection native, but use two wheel columns (hour/minute)
    // for precise and quick time selection in add/edit dose flows.
    final picked = await _showWheelTimePickerDialog(context);
    if (picked != null) onTimeChanged(picked);
  }

  /// Custom 24h time picker dialog powered by `wheel_picker`.
  ///
  /// Two wheels:
  /// - hour: 00..23
  /// - minute: 00..59
  ///
  /// We return TimeOfDay via Navigator.pop(), like showTimePicker().
  Future<TimeOfDay?> _showWheelTimePickerDialog(BuildContext context) async {
    // Controllers keep wheel position stable and allow smooth scrolling.
    final hourController = WheelPickerController(
      itemCount: 24,
      initialIndex: time.hour,
    );
    final minuteController = WheelPickerController(
      itemCount: 60,
      initialIndex: time.minute,
    );

    var selectedHour = time.hour;
    var selectedMinute = time.minute;

    final selected = await showDialog<TimeOfDay>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Set time'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Live preview so users always know the exact selected time.
                  Text(
                    '${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TimeWheel(
                        key: const ValueKey('time_wheel_hour'),
                        controller: hourController,
                        onIndexChanged: (index) {
                          setDialogState(() => selectedHour = index);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          ':',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      _TimeWheel(
                        key: const ValueKey('time_wheel_minute'),
                        controller: minuteController,
                        onIndexChanged: (index) {
                          setDialogState(() => selectedMinute = index);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      TimeOfDay(hour: selectedHour, minute: selectedMinute),
                    );
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    // Always dispose controllers created for this modal to avoid leaks.
    hourController.dispose();
    minuteController.dispose();

    return selected;
  }

  /// Format a TimeOfDay as 24h NATO: "14:30", "09:05".
  /// Public so other widgets can reuse the same format.
  static String format24h(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  /// Format date as "Mon, Feb 21" — short and readable.
  /// Made static + public so other widgets can reuse the same format
  /// (e.g., the recent logs list in LogDoseScreen).
  static String formatDate(DateTime d) {
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
    // DateTime.weekday: 1=Monday, 7=Sunday. Subtract 1 for 0-indexed array.
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }
}

/// Small reusable wheel for one time column (hour or minute).
///
/// Isolated to avoid repeating wheel style setup twice.
class _TimeWheel extends StatelessWidget {
  final WheelPickerController controller;
  final ValueChanged<int> onIndexChanged;

  const _TimeWheel({
    super.key,
    required this.controller,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleMedium;
    final dimmedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return SizedBox(
      width: 72,
      height: 140,
      child: WheelPicker(
        builder: (context, index) => Center(
          child: Text(index.toString().padLeft(2, '0'), style: textStyle),
        ),
        controller: controller,
        // 5 visible rows (center + 2 above + 2 below) keeps it compact.
        style: WheelPickerStyle(
          itemExtent: 28,
          squeeze: 1.1,
          diameterRatio: 1.2,
          surroundingOpacity: 0.25,
          magnification: 1.1,
          shiftAnimationStyle: const WheelShiftAnimationStyle(
            duration: Duration(milliseconds: 150),
            curve: Curves.easeOut,
          ),
        ),
        // Package callback includes interaction metadata; this widget only
        // needs the selected index for TimeOfDay updates.
        onIndexChanged: (index, _) => onIndexChanged(index),
        selectedIndexColor: dimmedColor.withAlpha(40),
      ),
    );
  }
}
