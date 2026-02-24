import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/dashboard/trackable_log_screen.dart';
import 'package:taper/utils/day_boundary.dart';
import 'package:taper/utils/taper_calculator.dart';

class DailyTotalsCard extends ConsumerStatefulWidget {
  final int trackableId;

  const DailyTotalsCard({super.key, required this.trackableId});

  @override
  ConsumerState<DailyTotalsCard> createState() => _DailyTotalsCardState();
}

class _DailyTotalsCardState extends ConsumerState<DailyTotalsCard> {
  static const _totalDays = 30;

  @override
  Widget build(BuildContext context) {
    final trackablesAsync = ref.watch(trackablesProvider);
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
        final trackable = trackables
            .where((t) => t.id == widget.trackableId)
            .firstOrNull;
        if (trackable == null) return const SizedBox.shrink();

        // Watch the active taper plan so the chart can overlay a target line.
        // `.value` is null both while loading and when no plan exists, which is
        // fine here because the chart should simply omit the overlay in both cases.
        final activePlan = ref
            .watch(activeTaperPlanProvider(trackable.id))
            .value;
        final trackableColor = Color(trackable.color);
        // Use the shared "now" provider so tests can freeze time and keep
        // chart date windows deterministic across calendar days.
        final now = ref.watch(nowProvider)();
        final todayBoundary = dayBoundary(now, boundaryHour: boundaryHour);

        final startBoundary = DateTime(
          todayBoundary.year,
          todayBoundary.month,
          todayBoundary.day - (_totalDays - 1),
          todayBoundary.hour,
        );
        final endBoundary = nextDayBoundary(now, boundaryHour: boundaryHour);

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrackableLogScreen(trackable: trackable),
            ),
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Container(
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            '${trackable.name} — Daily Totals',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '30 days',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    StreamBuilder<List<DoseLog>>(
                      stream: db.watchDosesBetween(
                        trackable.id,
                        startBoundary,
                        endBoundary,
                      ),
                      builder: (context, snapshot) {
                        final doses = snapshot.data ?? [];

                        if (doses.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'No doses in the last 30 days.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          );
                        }

                        final adapters = doses
                            .map((d) => _DoseLogAdapter(d))
                            .toList();

                        final dailyTotals = TaperCalculator.dailyTotals(
                          doses: adapters,
                          boundaryHour: boundaryHour,
                        );

                        final spots = <FlSpot>[];
                        var totalSum = 0.0;
                        for (var i = 0; i < _totalDays; i++) {
                          final date = DateTime(
                            startBoundary.year,
                            startBoundary.month,
                            startBoundary.day + i,
                            startBoundary.hour,
                          );
                          final amount = dailyTotals[date] ?? 0.0;
                          spots.add(FlSpot(i.toDouble(), amount));
                          totalSum += amount;
                        }

                        final daysWithData = dailyTotals.values
                            .where((v) => v > 0)
                            .length;
                        final avg = totalSum / _totalDays;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'avg: ${avg.toStringAsFixed(0)} ${trackable.unit}/day'
                              '${daysWithData < _totalDays ? ' ($daysWithData days with doses)' : ''}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),

                            const SizedBox(height: 12),

                            SizedBox(
                              height: 200,
                              child: _buildChart(
                                context,
                                spots: spots,
                                activePlan: activePlan,
                                trackableColor: trackableColor,
                                trackableUnit: trackable.unit,
                                startBoundary: startBoundary,
                                todayBoundary: todayBoundary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChart(
    BuildContext context, {
    required List<FlSpot> spots,
    required TaperPlan? activePlan,
    required Color trackableColor,
    required String trackableUnit,
    required DateTime startBoundary,
    required DateTime todayBoundary,
  }) {
    final axisColor = Theme.of(context).colorScheme.onSurfaceVariant;

    // Build one target point per day for the same X-axis as the totals series.
    // This mirrors the taper-progress chart logic, so "actual vs target" means
    // the same thing across both widgets.
    final taperTargetSpots = <FlSpot>[];
    if (activePlan != null) {
      for (var i = 0; i < _totalDays; i++) {
        final date = DateTime(
          startBoundary.year,
          startBoundary.month,
          startBoundary.day + i,
          startBoundary.hour,
        );
        final target = TaperCalculator.dailyTarget(
          startAmount: activePlan.startAmount,
          targetAmount: activePlan.targetAmount,
          startDate: activePlan.startDate,
          endDate: activePlan.endDate,
          queryDate: date,
        );
        taperTargetSpots.add(FlSpot(i.toDouble(), target));
      }
    }

    var maxY = spots.fold<double>(0, (max, s) => s.y > max ? s.y : max);
    // Include taper targets in Y scaling so the dashed line never gets clipped.
    if (taperTargetSpots.isNotEmpty) {
      final taperMax = taperTargetSpots.fold<double>(
        0,
        (max, s) => s.y > max ? s.y : max,
      );
      if (taperMax > maxY) maxY = taperMax;
    }
    final adjustedMaxY = maxY > 0 ? maxY * 1.1 : 1.0;

    final todayX = todayBoundary
        .difference(startBoundary)
        .inDays
        .toDouble()
        .clamp(0.0, (_totalDays - 1).toDouble());

    return LineChart(
      LineChartData(
        clipData: const FlClipData.all(),
        minX: 0,
        maxX: (_totalDays - 1).toDouble(),
        minY: 0,
        maxY: adjustedMaxY,

        lineBarsData: [
          // Dashed target line for the active taper plan.
          // This is intentionally muted so the solid totals series remains primary.
          if (taperTargetSpots.isNotEmpty)
            LineChartBarData(
              spots: taperTargetSpots,
              isCurved: false,
              color: axisColor.withAlpha(140),
              barWidth: 2,
              dashArray: [6, 4],
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: trackableColor,
            barWidth: 2,
            shadow: Shadow(color: trackableColor.withAlpha(80), blurRadius: 4),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: trackableColor,
                  strokeWidth: 0,
                );
              },
            ),
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
        ],

        extraLinesData: ExtraLinesData(
          verticalLines: [
            VerticalLine(
              x: todayX,
              color: axisColor.withAlpha(100),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ],
        ),

        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 7,
              getTitlesWidget: (value, meta) {
                final dayIndex = value.toInt();
                if (dayIndex < 0 || dayIndex > _totalDays - 1) {
                  return const SizedBox.shrink();
                }
                final date = DateTime(
                  startBoundary.year,
                  startBoundary.month,
                  startBoundary.day + dayIndex,
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
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),

        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),

        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          getTouchLineStart: (barData, spotIndex) => -double.infinity,
          getTouchLineEnd: (barData, spotIndex) => double.infinity,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                Theme.of(context).colorScheme.surfaceContainerHighest,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final dayIndex = spot.x.toInt();
                final date = DateTime(
                  startBoundary.year,
                  startBoundary.month,
                  startBoundary.day + dayIndex,
                );
                final dateStr = '${date.month}/${date.day}';
                // Target line is inserted before totals line, so barIndex 0 means
                // "target" whenever taperTargetSpots is present.
                final isTargetSpot =
                    taperTargetSpots.isNotEmpty && spot.barIndex == 0;
                final label = isTargetSpot ? 'Target' : 'Actual';
                final amountStr = '${spot.y.toStringAsFixed(0)} $trackableUnit';
                return LineTooltipItem(
                  '$dateStr\n$label: $amountStr',
                  TextStyle(
                    color: isTargetSpot
                        ? axisColor.withAlpha(220)
                        : trackableColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(
                  color: axisColor.withAlpha(80),
                  strokeWidth: 1,
                  dashArray: [3, 3],
                ),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, idx) {
                    return FlDotCirclePainter(
                      radius: 6,
                      // Use each series' own color so touching the dashed target
                      // line doesn't highlight with the totals color.
                      color: bar.color ?? trackableColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 160,
              height: 20,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 100,
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
}

class _DoseLogAdapter implements DoseLogLike {
  final DoseLog _doseLog;
  _DoseLogAdapter(this._doseLog);

  @override
  double get amount => _doseLog.amount;

  @override
  DateTime get loggedAt => _doseLog.loggedAt;
}
