import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/data/decay_model.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/log/add_dose_screen.dart';
import 'package:taper/screens/log/edit_dose_screen.dart';
import 'package:taper/screens/shared/quick_add_dose_dialog.dart';
import 'package:taper/utils/day_boundary.dart';
import 'package:taper/utils/decay_calculator.dart';
import 'package:taper/utils/significant_digits_formatter.dart';
import 'package:taper/utils/taper_calculator.dart';

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
                          final hour = value.toInt();
                          if (hour < 0 || hour > 24) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            '${hour.toString().padLeft(2, '0')}:00',
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

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: CalendarDatePicker(
              initialDate: initialDate,
              firstDate: DateTime(2020),
              // Allow selecting future dates so users can inspect planned days.
              lastDate: DateTime(2100),
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
