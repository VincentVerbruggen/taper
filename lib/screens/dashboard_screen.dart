import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/dashboard/widgets/trackable_card.dart';
import 'package:taper/utils/day_boundary.dart';

/// Dashboard tab — shows a card for each visible trackable with decay stats.
///
/// Each card loads independently via trackableCardDataProvider.family, so
/// they appear as their data becomes ready (staggered loading).
///
/// Includes a date navigation header: [<] [date label] [>]
/// Left arrow = previous day, right arrow = next day (disabled on today).
/// Tapping the date label opens a date picker for jumping to any date.
///
/// Like a Laravel dashboard with multiple Livewire components:
///   `@foreach($trackables as $trackable)`
///       `<livewire:trackable-card :id="$trackable->id" />`
///   `@endforeach`
///
/// ConsumerWidget because we watch the visible trackables provider.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackablesAsync = ref.watch(visibleTrackablesProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final boundaryHour = ref.watch(dayBoundaryHourProvider);

    return trackablesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (trackables) {
        // Empty state: no visible trackables configured.
        if (trackables.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'No visible trackables.\nGo to the Trackables tab to add or unhide one.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // SafeArea(bottom: false) pushes content below the status bar
        // without adding padding at the bottom (the tab bar handles that).
        // Like adding `padding-top: env(safe-area-inset-top)` in CSS.
        return SafeArea(
          bottom: false,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            // +1 for the header row at index 0.
            itemCount: trackables.length + 1,
            itemBuilder: (context, index) {
              // First item = date navigation header.
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildDateNav(context, ref, selectedDate, boundaryHour),
                );
              }

              // Subtract 1 to get the real trackable index (header took slot 0).
              final trackable = trackables[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TrackableCard(trackableId: trackable.id),
              );
            },
          ),
        );
      },
    );
  }

  /// Builds the date navigation header: [<] [date label] [>].
  ///
  /// - Left arrow: go to previous day
  /// - Date label: tappable, opens date picker
  /// - Right arrow: go to next day (disabled when on today)
  ///
  /// Like a date range picker header in a reporting dashboard.
  Widget _buildDateNav(
    BuildContext context,
    WidgetRef ref,
    DateTime? selectedDate,
    int boundaryHour,
  ) {
    final now = DateTime.now();
    final todayBoundary = dayBoundary(now, boundaryHour: boundaryHour);
    // If no date selected, we're in "live" mode (today).
    final isToday = selectedDate == null;
    final displayDate = selectedDate ?? todayBoundary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Previous day arrow.
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () =>
              ref.read(selectedDateProvider.notifier).previousDay(),
          tooltip: 'Previous day',
        ),

        // Tappable date label — opens a date picker.
        GestureDetector(
          onTap: () => _showDatePicker(context, ref, displayDate, boundaryHour),
          child: Text(
            _formatDateLabel(displayDate, todayBoundary, isToday),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),

        // Next day arrow — disabled when on today (no future data).
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: isToday
              ? null
              : () => ref.read(selectedDateProvider.notifier).nextDay(),
          tooltip: 'Next day',
        ),
      ],
    );
  }

  /// Formats the date label for the dashboard header.
  ///
  /// "Today" for live mode, "Yesterday" for the previous day,
  /// or "Wed, Feb 19" for older dates. Like a relative date formatter.
  String _formatDateLabel(
    DateTime displayDate,
    DateTime todayBoundary,
    bool isToday,
  ) {
    if (isToday) return 'Today';

    final yesterdayBoundary = todayBoundary.subtract(const Duration(days: 1));
    if (displayDate == yesterdayBoundary) return 'Yesterday';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[displayDate.weekday - 1]}, ${months[displayDate.month - 1]} ${displayDate.day}';
  }

  /// Opens a date picker dialog for jumping to a specific date.
  ///
  /// Restricts selection to past dates only (no future data exists).
  /// Like showDatePicker() in Flutter = the Material date picker dialog.
  void _showDatePicker(
    BuildContext context,
    WidgetRef ref,
    DateTime currentDate,
    int boundaryHour,
  ) async {
    final now = DateTime.now();
    final todayBoundary = dayBoundary(now, boundaryHour: boundaryHour);

    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      // Allow going back up to a year.
      firstDate: todayBoundary.subtract(const Duration(days: 365)),
      lastDate: todayBoundary,
    );

    if (picked != null) {
      // Convert the picked date to a day boundary time.
      final pickedBoundary = DateTime(
        picked.year,
        picked.month,
        picked.day,
        boundaryHour,
      );

      if (pickedBoundary == todayBoundary) {
        // User picked today — go to live mode.
        ref.read(selectedDateProvider.notifier).goToToday();
      } else {
        ref.read(selectedDateProvider.notifier).selectDate(pickedBoundary);
      }
    }
  }
}
