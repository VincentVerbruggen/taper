import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/utils/day_boundary.dart';
import 'package:taper/utils/taper_calculator.dart';

/// The headline taper feature: a progress chart showing actual daily consumption
/// vs. the plan's target line over weeks/months.
///
/// Layout:
///   - Plan summary: "400 → 100 mg · Feb 1 – Mar 15" with status chip
///   - Stats row: "Day X of Y" · "Today: 180 mg (target: 280)"
///   - Full-width LineChart (~300px) with target line + actual consumption
///
/// Like a project burn-down chart — the target is the ideal trajectory,
/// and the actual line shows real progress (or lack thereof).
class TaperProgressScreen extends ConsumerStatefulWidget {
  final Trackable trackable;
  final TaperPlan taperPlan;

  const TaperProgressScreen({
    super.key,
    required this.trackable,
    required this.taperPlan,
  });

  @override
  ConsumerState<TaperProgressScreen> createState() =>
      _TaperProgressScreenState();
}

class _TaperProgressScreenState extends ConsumerState<TaperProgressScreen> {
  /// Controls the zoom/pan transform of the chart.
  /// Like a Camera controller — tracks the current zoom level and pan offset
  /// so we can programmatically reset it back to the default view.
  final _transformController = TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final boundaryHour = ref.watch(dayBoundaryHourProvider);
    final plan = widget.taperPlan;
    final trackable = widget.trackable;
    final now = DateTime.now();
    final todayBoundary = dayBoundary(now, boundaryHour: boundaryHour);
    final trackableColor = Color(trackable.color);

    // Chart range: full taper period with small padding on each side.
    // Shows the entire planned trajectory so you can see the downward slope
    // and where you are on it (via the "today" vertical line).
    // Actual consumption dots only go up to today — future days aren't plotted.
    final chartStart = DateTime(
      plan.startDate.year, plan.startDate.month, plan.startDate.day - 3,
      plan.startDate.hour,
    );
    // Show the full plan + 3 days padding after end for maintenance context.
    final chartEnd = DateTime(
      plan.endDate.year, plan.endDate.month, plan.endDate.day + 3,
      plan.endDate.hour,
    );

    // Compute "Day X of Y" stats.
    final totalDays = plan.endDate.difference(plan.startDate).inDays;
    final elapsedDays = todayBoundary.difference(plan.startDate).inDays;
    final dayNumber = elapsedDays.clamp(0, totalDays);

    // Today's target from the taper plan.
    final todayTarget = TaperCalculator.dailyTarget(
      startAmount: plan.startAmount,
      targetAmount: plan.targetAmount,
      startDate: plan.startDate,
      endDate: plan.endDate,
      queryDate: todayBoundary,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taper Progress'),
        actions: [
          // Reset zoom button — snaps the chart back to the default 1x view.
          // Only visible when the user has zoomed in (transform != identity).
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            tooltip: 'Reset zoom',
            onPressed: () {
              // Animate back to the identity matrix (1x zoom, no pan offset).
              _transformController.value = Matrix4.identity();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Plan summary ---
            // "400 → 100 mg · Feb 1 – Mar 15" + status chip
            _buildPlanSummary(context, plan, trackable),

            const SizedBox(height: 12),

            // --- Stats row ---
            // "Day 14 of 42 · Today: 180 mg (target: 280)"
            _buildStatsRow(
              context,
              dayNumber: dayNumber,
              totalDays: totalDays,
              todayTarget: todayTarget,
              trackable: trackable,
              todayBoundary: todayBoundary,
              boundaryHour: boundaryHour,
              db: db,
            ),

            const SizedBox(height: 16),

            // --- Progress chart ---
            // Reactive: watches dose stream so adding/deleting doses updates the chart.
            // Wrapped in InteractiveViewer for pinch-to-zoom and pan gestures.
            // Like Google Maps: pinch to zoom into a specific week, drag to scroll.
            // fl_chart has no native zoom support, so we use Flutter's built-in
            // InteractiveViewer which applies a transform matrix to its child.
            SizedBox(
              height: 300,
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 1.0,   // Can't zoom out past the default view.
                maxScale: 5.0,   // Up to 5x zoom for inspecting individual days.
                constrained: true, // Stays within bounds at default zoom.
                // Smooth deceleration when the user releases a pan gesture —
                // lower = less friction = smoother coast to a stop.
                interactionEndFrictionCoefficient: 0.001,
                child: StreamBuilder<List<DoseLog>>(
                  // Query all doses within the chart range for the "actual" line.
                  stream: db.watchDosesBetween(
                    trackable.id, chartStart, chartEnd,
                  ),
                  builder: (context, snapshot) {
                    final doses = snapshot.data ?? [];

                    return _buildChart(
                      context,
                      doses: doses,
                      plan: plan,
                      chartStart: chartStart,
                      chartEnd: chartEnd,
                      todayBoundary: todayBoundary,
                      trackableColor: trackableColor,
                      boundaryHour: boundaryHour,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Plan summary: "400 → 100 mg · Feb 1 – Mar 15" with a status chip.
  Widget _buildPlanSummary(
    BuildContext context,
    TaperPlan plan,
    Trackable trackable,
  ) {
    final status = plan.isActive ? 'Active' : 'Inactive';
    // Status chip color: active = primary, inactive = surface variant.
    final chipColor = plan.isActive
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final chipTextColor = plan.isActive
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Expanded(
          child: Text(
            '${plan.startAmount.toStringAsFixed(0)} → ${plan.targetAmount.toStringAsFixed(0)} ${trackable.unit} · ${_formatDate(plan.startDate)} – ${_formatDate(plan.endDate)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(width: 8),
        // Material 3 chip for status.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: chipTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Stats row showing progress and today's values.
  /// Uses a StreamBuilder on today's doses to get the actual amount.
  Widget _buildStatsRow(
    BuildContext context, {
    required int dayNumber,
    required int totalDays,
    required double todayTarget,
    required Trackable trackable,
    required DateTime todayBoundary,
    required int boundaryHour,
    required AppDatabase db,
  }) {
    final nextBoundary = DateTime(
      todayBoundary.year, todayBoundary.month, todayBoundary.day + 1,
      todayBoundary.hour,
    );

    return StreamBuilder<List<DoseLog>>(
      // Watch just today's doses for the stats display.
      stream: db.watchDosesBetween(trackable.id, todayBoundary, nextBoundary),
      builder: (context, snapshot) {
        final todayDoses = snapshot.data ?? [];
        final todayActual = todayDoses.fold(0.0, (sum, d) => sum + d.amount);

        return Text(
          'Day $dayNumber of $totalDays · Today: ${todayActual.toStringAsFixed(0)} ${trackable.unit} (target: ${todayTarget.toStringAsFixed(0)})',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }

  /// Builds the progress LineChart with target line + actual consumption dots.
  ///
  /// X-axis: day index (0 = chartStart). Labels show date strings at weekly intervals.
  /// Two series:
  ///   1. Target line: dashed, muted. Diagonal from startAmount → targetAmount,
  ///      then flat at targetAmount for maintenance days.
  ///   2. Actual consumption: solid dots + line in the trackable's color.
  ///      One point per day = sum of all doses in that day boundary.
  Widget _buildChart(
    BuildContext context, {
    required List<DoseLog> doses,
    required TaperPlan plan,
    required DateTime chartStart,
    required DateTime chartEnd,
    required DateTime todayBoundary,
    required Color trackableColor,
    required int boundaryHour,
  }) {
    final axisColor = Theme.of(context).colorScheme.onSurfaceVariant;

    // Total number of days in the chart range.
    final totalChartDays = chartEnd.difference(chartStart).inDays;

    // --- Generate target line points ---
    // One point per day, linear interpolation from start → target → maintenance.
    final targetSpots = <FlSpot>[];
    for (var i = 0; i <= totalChartDays; i++) {
      final date = DateTime(
        chartStart.year, chartStart.month, chartStart.day + i,
        chartStart.hour,
      );
      final target = TaperCalculator.dailyTarget(
        startAmount: plan.startAmount,
        targetAmount: plan.targetAmount,
        startDate: plan.startDate,
        endDate: plan.endDate,
        queryDate: date,
      );
      targetSpots.add(FlSpot(i.toDouble(), target));
    }

    // --- Generate actual consumption points ---
    // Group doses by day boundary, sum amounts, create one dot per day.
    // Uses DoseLogAdapter to bridge Drift's DoseLog to TaperCalculator's DoseLogLike.
    final dailyTotals = TaperCalculator.dailyTotals(
      doses: doses.map((d) => _DoseLogAdapter(d)).toList(),
      boundaryHour: boundaryHour,
    );

    // Convert daily totals map to FlSpot list, only for days up to today.
    // Don't plot future days (they'd show as 0, which is misleading).
    final actualSpots = <FlSpot>[];
    for (var i = 0; i <= totalChartDays; i++) {
      final date = DateTime(
        chartStart.year, chartStart.month, chartStart.day + i,
        chartStart.hour,
      );
      // Don't plot days in the future.
      if (date.isAfter(todayBoundary)) break;
      final amount = dailyTotals[date] ?? 0.0;
      actualSpots.add(FlSpot(i.toDouble(), amount));
    }

    // Calculate "today" X position for the vertical dashed line.
    final todayX = todayBoundary.difference(chartStart).inDays.toDouble();

    // Find the max Y for chart scaling. Consider both target and actual values.
    var maxY = 0.0;
    for (final s in targetSpots) {
      if (s.y > maxY) maxY = s.y;
    }
    for (final s in actualSpots) {
      if (s.y > maxY) maxY = s.y;
    }
    final adjustedMaxY = maxY > 0 ? maxY * 1.1 : 1.0;

    return LineChart(
      LineChartData(
        clipData: const FlClipData.all(),
        minX: 0,
        maxX: totalChartDays.toDouble(),
        minY: 0,
        maxY: adjustedMaxY,

        // --- Line series ---
        lineBarsData: [
          // 1. Target line: dashed, muted color.
          // The ideal trajectory — what the plan prescribes each day.
          LineChartBarData(
            spots: targetSpots,
            isCurved: false, // Straight line segments for clarity
            color: axisColor.withAlpha(120),
            barWidth: 2,
            dashArray: [6, 4], // Dashed to distinguish from actual
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),

          // 2. Actual consumption: solid line with visible dots.
          // The real data — what the user actually consumed each day.
          if (actualSpots.isNotEmpty)
            LineChartBarData(
              spots: actualSpots,
              isCurved: false, // Straight connections between daily points
              color: trackableColor,
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {
                  return FlDotCirclePainter(
                    radius: 3,
                    color: trackableColor,
                    strokeWidth: 1,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: trackableColor.withAlpha(30),
              ),
            ),
        ],

        // --- Extra lines: vertical "today" line ---
        extraLinesData: ExtraLinesData(
          verticalLines: [
            if (todayX >= 0 && todayX <= totalChartDays)
              VerticalLine(
                x: todayX,
                color: axisColor.withAlpha(100),
                strokeWidth: 1,
                dashArray: [4, 4],
                label: VerticalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  style: TextStyle(
                    color: axisColor.withAlpha(180),
                    fontSize: 9,
                  ),
                  labelResolver: (_) => 'Today',
                ),
              ),
          ],
        ),

        // --- Axis labels ---
        titlesData: FlTitlesData(
          // Bottom: show date labels at regular intervals.
          // Every 7 days to avoid crowding. Shows "Feb 1", "Feb 8", etc.
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 7,
              getTitlesWidget: (value, meta) {
                // Convert day index back to a date.
                final dayIndex = value.toInt();
                if (dayIndex < 0 || dayIndex > totalChartDays) {
                  return const SizedBox.shrink();
                }
                final date = DateTime(
                  chartStart.year, chartStart.month, chartStart.day + dayIndex,
                  chartStart.hour,
                );
                return Text(
                  _formatShortDate(date),
                  style: TextStyle(
                    color: axisColor.withAlpha(150),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          // Left: amount labels.
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) {
                  return const SizedBox.shrink();
                }
                return Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(
                    color: axisColor.withAlpha(150),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),

        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),

        // Disable fl_chart's built-in touch handling — it conflicts with
        // InteractiveViewer's pinch-to-zoom and pan gestures. Without this,
        // both fight for the same touch events and neither works well.
        // The stats row above already shows today's actual vs target values.
        lineTouchData: const LineTouchData(handleBuiltInTouches: false),
      ),
    );
  }

  /// Format a date as "Feb 1" for compact chart labels.
  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  /// Format a date as "2/1" for very compact chart axis labels.
  String _formatShortDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}

/// Adapter that bridges Drift's DoseLog to TaperCalculator's DoseLogLike interface.
///
/// TaperCalculator uses DoseLogLike to avoid depending on Drift's generated code,
/// making it easier to test. This adapter wraps a real DoseLog for production use.
/// Like a Laravel Data Transfer Object wrapping an Eloquent model.
class _DoseLogAdapter implements DoseLogLike {
  final DoseLog _doseLog;
  _DoseLogAdapter(this._doseLog);

  @override
  double get amount => _doseLog.amount;

  @override
  DateTime get loggedAt => _doseLog.loggedAt;
}
