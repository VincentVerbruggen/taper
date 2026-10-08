import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/data/decay_model.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/dashboard/widgets/day_template_dialogs.dart';
import 'package:taper/screens/log/add_dose_screen.dart';
import 'package:taper/screens/log/edit_dose_screen.dart';
import 'package:taper/screens/shared/quick_add_dose_dialog.dart';
import 'package:taper/utils/day_boundary.dart';
import 'package:taper/utils/decay_calculator.dart';
import 'package:taper/utils/significant_digits_formatter.dart';
import 'package:taper/utils/taper_calculator.dart';
import 'package:taper/utils/template_time.dart';

/// One dose to insert in a bulk action (copy day / apply template).
///
/// A Dart 3 record: a lightweight, typed bundle of named fields with no class
/// boilerplate — like a typed PHP array shape `['amount' => float, ...]`.
/// The leading underscore keeps it private to this file.
typedef _NewDose = ({
  double amount,
  DateTime loggedAt,
  String? name,
  bool isPlanned,
});

/// Per-trackable daily log view.
///
/// Unlike the global Log tab, this screen is scoped to one trackable and one
/// selected day at a time (with previous/next/calendar navigation).
/// It also includes a day graph so users can inspect actual vs planned shape
/// before/after tweaking doses.
class TrackableLogScreen extends ConsumerStatefulWidget {
  final Trackable trackable;

  const TrackableLogScreen({super.key, required this.trackable});

  @override
  ConsumerState<TrackableLogScreen> createState() => _TrackableLogScreenState();
}

class _TrackableLogScreenState extends ConsumerState<TrackableLogScreen> {
  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final boundaryHour = ref.watch(dayBoundaryHourProvider);
    // Provider-driven clock keeps date labels deterministic in widget tests.
    final now = ref.watch(nowProvider)();
    final selectedDate = ref.watch(selectedDateProvider);
    final todayBoundary = dayBoundary(now, boundaryHour: boundaryHour);
    final selectedBoundary = selectedDate != null
        ? DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            boundaryHour,
          )
        : todayBoundary;
    final endBoundary = DateTime(
      selectedBoundary.year,
      selectedBoundary.month,
      selectedBoundary.day + 1,
      boundaryHour,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.trackable.name),
            Text(
              _formatDayLabel(selectedBoundary, todayBoundary),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Select date',
            onPressed: () => _showDatePicker(boundaryHour),
          ),
          if (selectedDate != null)
            IconButton(
              icon: const Icon(Icons.today),
              tooltip: 'Go to today',
              onPressed: () =>
                  ref.read(selectedDateProvider.notifier).goToToday(),
            ),
          // Overflow menu keeps the app bar from getting crowded — bulk/day
          // level actions live here, per-dose actions stay on the rows.
          PopupMenuButton<String>(
            tooltip: 'More actions',
            onSelected: (value) {
              // Dart 3 switch: no `break` needed, each case ends on its own.
              switch (value) {
                case 'copyFromDay':
                  _copyFromAnotherDay(
                    boundaryHour: boundaryHour,
                    selectedBoundary: selectedBoundary,
                    todayBoundary: todayBoundary,
                  );
                case 'saveTemplate':
                  _saveDayAsTemplate(
                    selectedBoundary: selectedBoundary,
                    endBoundary: endBoundary,
                  );
                case 'applyTemplate':
                  _applyTemplate(
                    boundaryHour: boundaryHour,
                    selectedBoundary: selectedBoundary,
                    todayBoundary: todayBoundary,
                  );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'copyFromDay',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.copy_all),
                  title: Text('Copy from another day…'),
                ),
              ),
              PopupMenuItem(
                value: 'saveTemplate',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.bookmark_add_outlined),
                  title: Text('Save day as template…'),
                ),
              ),
              PopupMenuItem(
                value: 'applyTemplate',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.bookmarks_outlined),
                  title: Text('Apply template…'),
                ),
              ),
            ],
          ),
        ],
      ),
      // Keep quick-add dialog for speed. Users can still adjust the timestamp
      // inside the dialog, and full planned editing lives in add/edit screens.
      floatingActionButton: FloatingActionButton(
        heroTag: 'trackableLogFab',
        onPressed: () async {
          final presetsList = await db.getPresets(widget.trackable.id);
          if (!context.mounted) return;
          showQuickAddDoseDialog(
            context: context,
            trackable: widget.trackable,
            db: db,
            presets: presetsList,
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<DoseLog>>(
        stream: db.watchDosesBetween(
          widget.trackable.id,
          selectedBoundary,
          endBoundary,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final doses = snapshot.data ?? [];
          final actualDoses = doses.where((d) => !d.isPlanned).toList();
          final plannedDoses = doses.where((d) => d.isPlanned).toList();
          final actualTotal = DecayCalculator.totalRawAmount(actualDoses);
          final plannedTotal = DecayCalculator.totalRawAmount(plannedDoses);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildDateNavRow(
                selectedBoundary: selectedBoundary,
                todayBoundary: todayBoundary,
                boundaryHour: boundaryHour,
              ),
              const SizedBox(height: 12),
              _buildDayGraph(
                selectedBoundary: selectedBoundary,
                endBoundary: endBoundary,
              ),
              const SizedBox(height: 12),
              _buildTotalsRow(
                boundary: selectedBoundary,
                actualTotal: actualTotal,
                plannedTotal: plannedTotal,
              ),
              const SizedBox(height: 8),
              if (doses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No doses logged on this day.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...doses.map((dose) => _buildDoseEntry(context, dose)),
            ],
          );
        },
      ),
    );
  }

  /// Previous/next row for one-day browsing.
  Widget _buildDateNavRow({
    required DateTime selectedBoundary,
    required DateTime todayBoundary,
    required int boundaryHour,
  }) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous day',
          onPressed: () =>
              ref.read(selectedDateProvider.notifier).previousDay(),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showDatePicker(boundaryHour),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
          // Future browsing is allowed for planned doses.
          onPressed: () => ref.read(selectedDateProvider.notifier).nextDay(),
        ),
      ],
    );
  }

  /// Day graph for this trackable (actual solid + projected dashed).
  ///
  /// We reuse the same provider as dashboard cards so decay math and windows
  /// stay consistent across surfaces.
  Widget _buildDayGraph({
    required DateTime selectedBoundary,
    required DateTime endBoundary,
  }) {
    final dataAsync = ref.watch(
      trackableCardDataForSelectedDateProvider(widget.trackable.id),
    );
    final axisColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final trackableColor = Color(widget.trackable.color);
    final hasDecay =
        DecayModel.fromString(widget.trackable.decayModel) != DecayModel.none;

    if (!hasDecay) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No decay graph for this trackable.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return dataAsync.when(
      loading: () => const Card(
        child: SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Chart error: $error'),
        ),
      ),
      data: (data) {
        final actualPoints = data.curvePoints
            .where(
              (p) =>
                  !p.time.isBefore(selectedBoundary) &&
                  !p.time.isAfter(endBoundary),
            )
            .toList();
        final projectedPoints = data.projectedCurvePoints
            .where(
              (p) =>
                  !p.time.isBefore(selectedBoundary) &&
                  !p.time.isAfter(endBoundary),
            )
            .toList();

        if (actualPoints.isEmpty) {
          return const SizedBox.shrink();
        }

        final actualSpots = actualPoints.map((p) {
          final x = p.time.difference(selectedBoundary).inMinutes / 60.0;
          return FlSpot(x, p.amount);
        }).toList();
        final projectedSpots = projectedPoints.map((p) {
          final x = p.time.difference(selectedBoundary).inMinutes / 60.0;
          return FlSpot(x, p.amount);
        }).toList();

        var maxY = actualSpots.fold<double>(
          0,
          (max, s) => s.y > max ? s.y : max,
        );
        for (final s in projectedSpots) {
          if (s.y > maxY) maxY = s.y;
        }
        final visibleMaxY = maxY > 0 ? maxY * 1.1 : 1.0;

        final lineBars = <LineChartBarData>[
          LineChartBarData(
            spots: actualSpots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: trackableColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  trackableColor.withAlpha(50),
                  trackableColor.withAlpha(0),
                ],
              ),
            ),
          ),
        ];

        if (data.hasPlannedDoses && projectedSpots.isNotEmpty) {
          lineBars.add(
            LineChartBarData(
              spots: projectedSpots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: trackableColor.withAlpha(180),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              dashArray: [8, 5],
              belowBarData: BarAreaData(show: false),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 24,
                  minY: 0,
                  maxY: visibleMaxY,
                  lineBarsData: lineBars,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 6,
                        getTitlesWidget: (value, meta) {
                          final hoursFromBoundary = value.toInt();
                          if (hoursFromBoundary < 0 || hoursFromBoundary > 24) {
                            return const SizedBox.shrink();
                          }
                          // x = 0 is the day boundary (e.g. 05:00), not
                          // midnight — convert the axis value (hours since the
                          // boundary) into real wall-clock time so the labels
                          // start at the start-of-day time instead of 00:00.
                          final labelTime = selectedBoundary.add(
                            Duration(hours: hoursFromBoundary),
                          );
                          return Text(
                            '${labelTime.hour.toString().padLeft(2, '0')}:00',
                            style: TextStyle(
                              color: axisColor.withAlpha(160),
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.min || value == meta.max) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            // Show up to 3 significant digits so tiny values
                            // are still visible while keeping labels compact.
                            formatWithSignificantDigits(value),
                            style: TextStyle(
                              color: axisColor.withAlpha(160),
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  // Replace fl_chart's default tooltip (which prints raw,
                  // full-precision numbers) with a clock time + a value rounded
                  // to 3 significant figures — matching the dashboard card.
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      getTooltipItems: (spots) {
                        // The projected (dashed) line is the 2nd bar, and only
                        // present when there are planned doses to project.
                        final projectedIndex =
                            (data.hasPlannedDoses && projectedSpots.isNotEmpty)
                            ? 1
                            : null;
                        return spots.map((spot) {
                          // spot.x is hours since the boundary — same mapping
                          // as the axis labels above.
                          final spotTime = selectedBoundary.add(
                            Duration(minutes: (spot.x * 60).round()),
                          );
                          final timeStr =
                              '${spotTime.hour.toString().padLeft(2, '0')}:${spotTime.minute.toString().padLeft(2, '0')}';
                          final amount = formatWithSignificantDigits(spot.y);
                          final isProjected = spot.barIndex == projectedIndex;
                          final label = isProjected ? 'Projected' : 'Amount';
                          return LineTooltipItem(
                            '$timeStr\n$label: $amount ${widget.trackable.unit}',
                            TextStyle(
                              color: isProjected
                                  ? trackableColor.withAlpha(170)
                                  : trackableColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Daily totals row (actual + optional planned + taper target).
  Widget _buildTotalsRow({
    required DateTime boundary,
    required double actualTotal,
    required double plannedTotal,
  }) {
    final activePlan = ref
        .watch(activeTaperPlanProvider(widget.trackable.id))
        .value;
    final taperTarget = activePlan == null
        ? null
        : TaperCalculator.dailyTarget(
            startAmount: activePlan.startAmount,
            targetAmount: activePlan.targetAmount,
            startDate: activePlan.startDate,
            endDate: activePlan.endDate,
            queryDate: boundary,
          );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Daily total',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Flexible(
          child: Text(
            _formatTotalsText(
              actualTotal: actualTotal,
              plannedTotal: plannedTotal,
              taperTarget: taperTarget,
              unit: widget.trackable.unit,
            ),
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTotalsText({
    required double actualTotal,
    required double plannedTotal,
    required double? taperTarget,
    required String unit,
  }) {
    final actual = actualTotal.toStringAsFixed(0);
    final planned = plannedTotal.toStringAsFixed(0);
    final target = taperTarget?.toStringAsFixed(0);

    var text = '$actual $unit';
    if (plannedTotal > 0) {
      text += ' (+$planned planned)';
    }
    if (target != null) {
      text += ' / $target';
    }
    return text;
  }

  /// Single dose row.
  Widget _buildDoseEntry(BuildContext context, DoseLog dose) {
    final h = dose.loggedAt.hour.toString().padLeft(2, '0');
    final m = dose.loggedAt.minute.toString().padLeft(2, '0');
    final time = '$h:$m';

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
          onTap: () => _editDose(dose),
          child: ListTile(
            title: Text(
              dose.amount == 0
                  ? 'Skipped'
                  : dose.name != null
                  ? '${dose.name!} (${dose.amount.toStringAsFixed(0)} ${widget.trackable.unit})'
                  : '${dose.amount.toStringAsFixed(0)} ${widget.trackable.unit}',
            ),
            subtitle: Text(dose.isPlanned ? '$time • Planned' : time),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: 'Copy dose',
                  onPressed: () => _copyDose(dose),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Delete dose',
                  onPressed: () => _deleteDoseWithUndo(dose),
                  color: Theme.of(context).colorScheme.error,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deleteDoseWithUndo(DoseLog dose) async {
    final db = ref.read(databaseProvider);
    await db.deleteDoseLog(dose.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        showCloseIcon: true,
        persist: false,
        duration: const Duration(seconds: 6),
        content: Text(
          'Deleted ${dose.amount.toStringAsFixed(0)} ${widget.trackable.unit}',
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

  void _copyDose(DoseLog dose) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddDoseScreen(
          // Keep the original date, but use current time for the new log so
          // copy works as a planning shortcut instead of a full timestamp clone.
          initialTrackableId: dose.trackableId,
          initialAmount: dose.amount,
          initialName: dose.name,
          initialDate: dose.loggedAt,
          useCurrentTimeForInitialDate: true,
          initialIsPlanned: dose.isPlanned,
        ),
      ),
    );
  }

  void _editDose(DoseLog dose) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditDoseScreen(
          entry: DoseLogWithTrackable(
            doseLog: dose,
            trackable: widget.trackable,
          ),
        ),
      ),
    );
  }

  Future<void> _showDatePicker(int boundaryHour) async {
    final now = ref.read(nowProvider)();
    final selectedDate = ref.read(selectedDateProvider);
    final initialDate = selectedDate != null
        ? DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
        : DateTime(now.year, now.month, now.day);

    final picked = await _pickDay(initialDate: initialDate);
    if (picked == null || !mounted) return;

    ref
        .read(selectedDateProvider.notifier)
        .selectDate(
          DateTime(picked.year, picked.month, picked.day, boundaryHour),
        );
  }

  /// Shared calendar dialog. Returns the picked date, or null if dismissed.
  ///
  /// Think of it like a blade partial: one calendar markup reused by both the
  /// "jump to date" action and the "copy from day" action, each doing something
  /// different with the returned value.
  Future<DateTime?> _pickDay({
    required DateTime initialDate,
    String? title,
  }) async {
    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      title,
                      style: Theme.of(dialogContext).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // CalendarDatePicker lays out with an Expanded internally, so
                // it needs a bounded height. Inside a plain Dialog it inherits
                // one; inside this Column (mainAxisSize.min) it would not, so
                // we give it an explicit box.
                SizedBox(
                  height: 340,
                  child: CalendarDatePicker(
                    initialDate: initialDate,
                    firstDate: DateTime(2020),
                    // Allow future dates so users can inspect/plan ahead.
                    lastDate: DateTime(2100),
                    onDateChanged: (picked) =>
                        Navigator.pop(dialogContext, picked),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Copies every entry from a picked source day into the day being viewed.
  ///
  /// Time-of-day is preserved: a 08:30 dose on the source day becomes an 08:30
  /// dose on the target day. Entries that fall after midnight but before the
  /// day boundary (e.g. a 02:00 dose belonging to the previous "day") keep that
  /// relationship because we shift by whole calendar days, not by a Duration.
  Future<void> _copyFromAnotherDay({
    required int boundaryHour,
    required DateTime selectedBoundary,
    required DateTime todayBoundary,
  }) async {
    final db = ref.read(databaseProvider);
    final messenger = ScaffoldMessenger.of(context);

    // Default the picker to the day before the one being viewed — repeating
    // yesterday into today is by far the most common case.
    final defaultSource = DateTime(
      selectedBoundary.year,
      selectedBoundary.month,
      selectedBoundary.day - 1,
    );

    final picked = await _pickDay(
      initialDate: defaultSource,
      title: 'Copy entries from…',
    );
    if (picked == null || !mounted) return;

    final sourceBoundary = DateTime(
      picked.year,
      picked.month,
      picked.day,
      boundaryHour,
    );

    // Copying a day onto itself would silently double it — almost certainly a
    // mis-tap, so we stop instead of destroying the day's data.
    if (sourceBoundary == selectedBoundary) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("That's the day you're already viewing."),
        ),
      );
      return;
    }

    final sourceEnd = DateTime(
      sourceBoundary.year,
      sourceBoundary.month,
      sourceBoundary.day + 1,
      boundaryHour,
    );

    // One-shot read (not a stream): we're about to write into the same table
    // and don't want the query re-firing underneath us mid-copy.
    final sourceDoses = await db.getDosesBetween(
      widget.trackable.id,
      sourceBoundary,
      sourceEnd,
    );
    if (!mounted) return;

    final sourceLabel = _formatDayLabel(sourceBoundary, todayBoundary);

    if (sourceDoses.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('No entries on $sourceLabel to copy.')),
      );
      return;
    }

    // Whole-day shift computed in UTC so a DST change in between can't turn a
    // 24h difference into 23h and round the day count down.
    final dayShift = _calendarDaysBetween(sourceBoundary, selectedBoundary);
    // Anything landing on a future day is an intention, not something consumed,
    // so it becomes a planned dose. Today/past keeps whatever the source was.
    final targetIsFuture = selectedBoundary.isAfter(todayBoundary);

    final newDoses = sourceDoses.map((dose) {
      final src = dose.loggedAt;
      // DateTime() normalises day overflow (Feb 28 + 2 → Mar 2) and DST, so we
      // rebuild the timestamp instead of adding a Duration.
      final newLoggedAt = DateTime(
        src.year,
        src.month,
        src.day + dayShift,
        src.hour,
        src.minute,
        src.second,
      );
      return (
        amount: dose.amount,
        loggedAt: newLoggedAt,
        name: dose.name,
        isPlanned: targetIsFuture ? true : dose.isPlanned,
      );
    }).toList();

    final count = newDoses.length;
    await _insertBatchWithUndo(
      db: db,
      messenger: messenger,
      doses: newDoses,
      message:
          'Copied $count ${count == 1 ? 'entry' : 'entries'} from $sourceLabel'
          '${targetIsFuture ? ' as planned' : ''}',
    );
  }

  /// Saves the viewed day's entries as a named template.
  ///
  /// Skipped entries (amount 0) are left out: a template is a plan of doses,
  /// and a skip only records that a dose didn't happen.
  Future<void> _saveDayAsTemplate({
    required DateTime selectedBoundary,
    required DateTime endBoundary,
  }) async {
    final db = ref.read(databaseProvider);
    final messenger = ScaffoldMessenger.of(context);

    final doses = (await db.getDosesBetween(
      widget.trackable.id,
      selectedBoundary,
      endBoundary,
    )).where((d) => d.amount > 0).toList();
    if (!mounted) return;

    if (doses.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No entries to save.')),
      );
      return;
    }

    // Load existing names up front so the dialog can spot an overwrite.
    final existing = await db.getDayTemplates(widget.trackable.id);
    if (!mounted) return;

    final choice = await showSaveTemplateDialog(
      context: context,
      existing: existing,
    );
    if (choice == null) return;

    await db.saveDayTemplate(
      trackableId: widget.trackable.id,
      name: choice.name,
      doses: doses,
      overwriteTemplateId: choice.overwriteTemplateId,
    );
    if (!mounted) return;

    final count = doses.length;
    messenger.showSnackBar(
      SnackBar(
        showCloseIcon: true,
        content: Text(
          "Saved template '${choice.name}' "
          "($count ${count == 1 ? 'entry' : 'entries'})",
        ),
      ),
    );
  }

  /// Adds a picked template's entries to the viewed day.
  ///
  /// Same planned rule as copying a day: on a future day every entry becomes
  /// planned, otherwise each entry keeps the flag it was saved with.
  Future<void> _applyTemplate({
    required int boundaryHour,
    required DateTime selectedBoundary,
    required DateTime todayBoundary,
  }) async {
    final db = ref.read(databaseProvider);
    final messenger = ScaffoldMessenger.of(context);

    final template = await showApplyTemplateDialog(
      context: context,
      trackableId: widget.trackable.id,
    );
    if (template == null) return;

    final entries = await db.getDayTemplateEntries(template.id);
    if (!mounted) return;

    final targetIsFuture = selectedBoundary.isAfter(todayBoundary);
    final newDoses = entries
        .map(
          (e) => (
            amount: e.amount,
            // Entries before the boundary hour (e.g. 02:00) land on the next
            // calendar date, so they still fall inside the viewed day.
            loggedAt: placeOnDay(e.time, selectedBoundary, boundaryHour),
            name: e.name,
            isPlanned: targetIsFuture || e.isPlanned,
          ),
        )
        .toList();

    final count = newDoses.length;
    await _insertBatchWithUndo(
      db: db,
      messenger: messenger,
      doses: newDoses,
      message:
          "Applied '${template.name}' "
          "($count ${count == 1 ? 'entry' : 'entries'})"
          '${targetIsFuture ? ' as planned' : ''}',
    );
  }

  /// Inserts [doses] for this trackable, then shows [message] with an Undo
  /// action that deletes exactly the rows created here.
  ///
  /// Shared by "Copy from another day" and "Apply template" — both end in the
  /// same "bulk insert + undoable snackbar" step.
  ///
  /// [db] and [messenger] are passed in instead of looked up here because
  /// callers must grab them BEFORE their first `await`: after an await the
  /// screen may be gone, and Riverpod throws if `ref` is used after unmount.
  Future<void> _insertBatchWithUndo({
    required AppDatabase db,
    required ScaffoldMessengerState messenger,
    required List<_NewDose> doses,
    required String message,
  }) async {
    // One insertDoseLog per row (not a single transaction): insertDoseLog
    // fires the reminder scheduler in the background, and that work would run
    // against an already-closed transaction if we wrapped the loop in one.
    final insertedIds = <int>[];
    for (final dose in doses) {
      insertedIds.add(
        await db.insertDoseLog(
          widget.trackable.id,
          dose.amount,
          dose.loggedAt,
          name: dose.name,
          isPlanned: dose.isPlanned,
        ),
      );
    }

    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        showCloseIcon: true,
        // A snackbar with an action stays up until dismissed unless persist
        // is false — we want it to time out like the other snackbars.
        persist: false,
        duration: const Duration(seconds: 6),
        content: Text(message),
        action: SnackBarAction(
          label: 'Undo',
          // Undo only removes the rows we just created, so pre-existing
          // entries on this day are never touched.
          onPressed: () {
            for (final id in insertedIds) {
              db.deleteDoseLog(id);
            }
          },
        ),
      ),
    );
  }

  /// Whole calendar days between two local dates, ignoring time-of-day.
  ///
  /// Uses UTC copies of the date parts so DST transitions (a 23h or 25h local
  /// "day") can't skew the count.
  int _calendarDaysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// Formats a day boundary into a readable label.
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
}
