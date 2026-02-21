import 'package:flutter/material.dart';

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

        // Time chip — tap to open time picker
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickTime(context),
            icon: const Icon(Icons.access_time, size: 18),
            label: Text(time.format(context)),
          ),
        ),
      ],
    );
  }

  void _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      // Allow logging up to 7 days in the past (forgot to log yesterday's coffee).
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
    );
    if (picked != null) onDateChanged(picked);
  }

  void _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: time,
    );
    if (picked != null) onTimeChanged(picked);
  }

  /// Format date as "Mon, Feb 21" — short and readable.
  /// Made static + public so other widgets can reuse the same format
  /// (e.g., the recent logs list in LogDoseScreen).
  static String formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    // DateTime.weekday: 1=Monday, 7=Sunday. Subtract 1 for 0-indexed array.
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }
}
