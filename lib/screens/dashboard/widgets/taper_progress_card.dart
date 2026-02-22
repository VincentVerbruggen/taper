import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/dashboard/taper_progress_screen.dart';
import 'package:taper/utils/day_boundary.dart';
import 'package:taper/utils/taper_calculator.dart';

/// Inline dashboard card showing taper plan progress for a trackable.
///
/// A compact version of TaperProgressScreen — renders a small chart with
/// target + actual lines inside a Card. Tapping navigates to the full screen.
///
/// Shows an empty state when no active taper plan exists (e.g., user deleted it).
/// This prevents a crash if a taper_progress widget outlives its plan.
///
/// Like a Livewire component that independently loads its own data:
///   `<livewire:taper-progress-card :trackableId="$id" />`
class TaperProgressCard extends ConsumerWidget {
  final int trackableId;

  const TaperProgressCard({super.key, required this.trackableId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch all the data we need: the trackable (for name/color/unit),
    // the active plan (for chart data), and settings.
    final trackablesAsync = ref.watch(trackablesProvider);
    final planAsync = ref.watch(activeTaperPlanProvider(trackableId));
    final boundaryHour = ref.watch(dayBoundaryHourProvider);
    final db = ref.watch(databaseProvider);

    return trackablesAsync.when(
      loading: () => _buildLoadingSkeleton(context),
      error: (e, s) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $e'),
        ),
      ),
      data: (trackables) {
        final trackable =
            trackables.where((t) => t.id == trackableId).firstOrNull;
        if (trackable == null) {
          return const SizedBox.shrink();
        }

        final trackableColor = Color(trackable.color);

        return planAsync.when(
          loading: () => _buildLoadingSkeleton(context),
          error: (e, s) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: $e'),
            ),
          ),
          data: (plan) {
            // No active plan — show a graceful empty state.
            // This can happen if the user deletes the plan but keeps the widget.
            if (plan == null) {
              return _buildEmptyState(context, trackable);
            }

            // Tapping the card navigates to the full TaperProgressScreen.
            // HitTestBehavior.opaque ensures taps on empty areas register.
            // The chart inside uses IgnorePointer so it doesn't eat taps.
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TaperProgressScreen(
                    trackable: trackable,
                    taperPlan: plan,
                  ),
                ),
              ),
              child: _buildCard(
                context,
                trackable: trackable,
                plan: plan,
                trackableColor: trackableColor,
                boundaryHour: boundaryHour,
                db: db,
              ),
            );
          },
        );
      },
    );
  }

  /// Loading skeleton matching the TrackableCard pattern.
  Widget _buildLoadingSkeleton(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 20,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 200,
              height: 14,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Empty state when no active taper plan exists for this trackable.
  Widget _buildEmptyState(BuildContext context, Trackable trackable) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: Color(trackable.color), width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${trackable.name} — Taper Progress',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No active taper plan.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the full card with chart and summary.
  Widget _buildCard(
    BuildContext context, {
    required Trackable trackable,
    required TaperPlan plan,
    required Color trackableColor,
    required int boundaryHour,
    required AppDatabase db,
  }) {
    final now = DateTime.now();
    final todayBoundary = dayBoundary(now, boundaryHour: boundaryHour);

    // Chart range: full taper period so you can see the entire planned
    // trajectory. The "today" vertical line shows where you are on it.
    // Actual consumption dots only go up to today (future days aren't plotted).
    // Like a Gantt chart — you see the whole project, with progress so far.
    final chartStart = plan.startDate;
    final chartEnd = plan.endDate;

    // Day progress stats.
    final totalDays = plan.endDate.difference(plan.startDate).inDays;
    final elapsedDays = todayBoundary.difference(plan.startDate).inDays;
    final dayNumber = elapsedDays.clamp(0, totalDays);

    // Today's target from the plan.
    final todayTarget = TaperCalculator.dailyTarget(
      startAmount: plan.startAmount,
      targetAmount: plan.targetAmount,
      startDate: plan.startDate,
      endDate: plan.endDate,
      queryDate: todayBoundary,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        // Left border accent in the trackable's color — matching TrackableCard style.
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: trackableColor, width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row: trackable name + "Taper Progress" label.
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      '${trackable.name} — Taper',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Compact stats: "Day X of Y".
                  Text(
                    'Day $dayNumber of $totalDays',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Plan summary: "400 → 100 mg · target: 280".
              Text(
                '${plan.startAmount.toStringAsFixed(0)} → ${plan.targetAmount.toStringAsFixed(0)} ${trackable.unit} · target: ${todayTarget.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 12),

              // Inline chart — 200px height, no zoom/pan (card is too small).
              // Uses StreamBuilder to reactively update when doses change.
              // IgnorePointer prevents the LineChart from absorbing tap events
              // that should go to the GestureDetector wrapping the whole card.
              IgnorePointer(
                child: SizedBox(
                height: 200,
                child: StreamBuilder<List<DoseLog>>(
                  stream: db.watchDosesBetween(
                    trackable.id,
                    chartStart,
                    chartEnd,
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
      ),
    );
  }

  /// Builds the inline progress LineChart.
  ///
  /// Adapted from TaperProgressScreen._buildChart() but simplified:
  /// no InteractiveViewer, no touch handling, fits in 200px.
  /// Same two data series: dashed target line + solid actual dots.
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
    final totalChartDays = chartEnd.difference(chartStart).inDays;

    // Generate target line points (one per day).
    final targetSpots = <FlSpot>[];
    for (var i = 0; i <= totalChartDays; i++) {
      final date = DateTime(
        chartStart.year,
        chartStart.month,
        chartStart.day + i,
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

    // Generate actual consumption points (sum doses per day boundary).
    final dailyTotals = TaperCalculator.dailyTotals(
      doses: doses.map((d) => _DoseLogAdapter(d)).toList(),
      boundaryHour: boundaryHour,
    );

    final actualSpots = <FlSpot>[];
    for (var i = 0; i <= totalChartDays; i++) {
      final date = DateTime(
        chartStart.year,
        chartStart.month,
        chartStart.day + i,
        chartStart.hour,
      );
      if (date.isAfter(todayBoundary)) break;
      final amount = dailyTotals[date] ?? 0.0;
      actualSpots.add(FlSpot(i.toDouble(), amount));
    }

    // "Today" vertical line position.
    final todayX = todayBoundary.difference(chartStart).inDays.toDouble();

    // Max Y for scaling.
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
        lineBarsData: [
          // Target line: dashed, muted.
          LineChartBarData(
            spots: targetSpots,
            isCurved: false,
            color: axisColor.withAlpha(120),
            barWidth: 2,
            dashArray: [6, 4],
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
          // Actual consumption: solid + dots.
          if (actualSpots.isNotEmpty)
            LineChartBarData(
              spots: actualSpots,
              isCurved: false,
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
        // Vertical "today" line.
        extraLinesData: ExtraLinesData(
          verticalLines: [
            if (todayX >= 0 && todayX <= totalChartDays)
              VerticalLine(
                x: todayX,
                color: axisColor.withAlpha(100),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
          ],
        ),
        titlesData: FlTitlesData(
          // Bottom axis: date labels every 7 days.
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 7,
              getTitlesWidget: (value, meta) {
                final dayIndex = value.toInt();
                if (dayIndex < 0 || dayIndex > totalChartDays) {
                  return const SizedBox.shrink();
                }
                final date = DateTime(
                  chartStart.year,
                  chartStart.month,
                  chartStart.day + dayIndex,
                  chartStart.hour,
                );
                return Text(
                  '${date.month}/${date.day}',
                  style: TextStyle(
                    color: axisColor.withAlpha(150),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          // Left axis: amount labels.
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
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        // Disable touch handling — card is too small for meaningful interaction.
        // Users tap the whole card to get to the full-screen version instead.
        lineTouchData: const LineTouchData(handleBuiltInTouches: false),
      ),
    );
  }
}

/// Adapter bridging Drift's DoseLog to TaperCalculator's DoseLogLike interface.
/// Same pattern as TaperProgressScreen's _DoseLogAdapter.
class _DoseLogAdapter implements DoseLogLike {
  final DoseLog _doseLog;
  _DoseLogAdapter(this._doseLog);

  @override
  double get amount => _doseLog.amount;

  @override
  DateTime get loggedAt => _doseLog.loggedAt;
}
