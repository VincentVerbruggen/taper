import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/data/decay_model.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/dashboard/trackable_log_screen.dart';
import 'package:taper/utils/day_boundary.dart';
import 'package:taper/utils/decay_calculator.dart';
import 'package:taper/utils/significant_digits_formatter.dart';
import 'package:taper/utils/taper_calculator.dart';

/// Dashboard card: peak ACTIVE concentration per day over the past 30 days.
///
/// This is the decay-aware sibling of [DailyTotalsCard]. Daily totals sums the
/// raw amount you put in each day; this card instead runs the pharmacokinetic
/// decay curve and plots the single highest point your body reached that day.
///
/// Why that's different/useful: if you spread the same total dose across the day
/// your raw total is unchanged, but your peak concentration drops. This card
/// surfaces that — a good signal when the goal is "feel less spiked", not just
/// "consume less".
///
/// Only meaningful for trackables that actually decay (exponential/linear). For
/// a "none" model we show a hint instead of a flat/meaningless chart.
class DailyMaxConcentrationCard extends ConsumerStatefulWidget {
  final int trackableId;

  const DailyMaxConcentrationCard({super.key, required this.trackableId});

  @override
  ConsumerState<DailyMaxConcentrationCard> createState() =>
      _DailyMaxConcentrationCardState();
}

class _DailyMaxConcentrationCardState
    extends ConsumerState<DailyMaxConcentrationCard> {
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

        final trackableColor = Color(trackable.color);
        final model = DecayModel.fromString(trackable.decayModel);

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
                            '${trackable.name} — Daily Max',
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

                    // A "none" trackable never decays, so a peak-concentration
                    // curve would just mirror raw intake — point the user at the
                    // Daily Totals card instead.
                    if (model == DecayModel.none)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No decay model — peak concentration only applies to '
                          'trackables that decay. Use the Daily Totals card '
                          'instead.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      )
                    else
                      StreamBuilder<List<DoseLog>>(
                        // Look back beyond the 30-day window so doses logged just
                        // before the window's first day still contribute their
                        // decaying tail to that day's peak. The lookback mirrors
                        // the decay-card provider's window logic.
                        stream: db.watchDosesBetween(
                          trackable.id,
                          startBoundary.subtract(
                            _decayLookback(trackable, model),
                          ),
                          endBoundary,
                        ),
                        builder: (context, snapshot) {
                          final doses = (snapshot.data ?? [])
                              // Peaks should reflect what was actually consumed,
                              // not projected/planned future doses.
                              .where((d) => !d.isPlanned)
                              .toList();

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

                          // Sample the active-amount curve across the whole
                          // window using the trackable's own decay math, then
                          // bucket each day to its single highest sample.
                          final curve = _generateCurve(
                            doses: doses,
                            trackable: trackable,
                            model: model,
                            startTime: startBoundary,
                            endTime: endBoundary,
                          );
                          final dailyPeaks = TaperCalculator.dailyPeaks(
                            curve: curve,
                            boundaryHour: boundaryHour,
                          );

                          final spots = <FlSpot>[];
                          var peakSum = 0.0;
                          var overallPeak = 0.0;
                          for (var i = 0; i < _totalDays; i++) {
                            final date = DateTime(
                              startBoundary.year,
                              startBoundary.month,
                              startBoundary.day + i,
                              startBoundary.hour,
                            );
                            final amount = dailyPeaks[date] ?? 0.0;
                            spots.add(FlSpot(i.toDouble(), amount));
                            peakSum += amount;
                            if (amount > overallPeak) overallPeak = amount;
                          }

                          final daysWithData = dailyPeaks.values
                              .where((v) => v > 0)
                              .length;
                          final avgPeak = peakSum / _totalDays;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'avg peak: ${formatWithSignificantDigits(avgPeak)} '
                                '${trackable.unit} · '
                                'highest: ${formatWithSignificantDigits(overallPeak)} '
                                '${trackable.unit}'
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
                                  trackableColor: trackableColor,
                                  trackableUnit: trackable.unit,
                                  startBoundary: startBoundary,
                                  todayBoundary: todayBoundary,
                                  average: avgPeak,
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

  /// How far before the window to fetch doses so their decaying tail still
  /// counts toward early days' peaks. Mirrors the decay-card provider:
  ///   - exponential: 10 × half-life (< 0.1% remains beyond that)
  ///   - linear: 24h (conservative; small doses deplete quickly)
  Duration _decayLookback(Trackable trackable, DecayModel model) {
    return switch (model) {
      DecayModel.exponential => Duration(
        hours: (trackable.halfLifeHours! * 10).ceil(),
      ),
      DecayModel.linear => const Duration(hours: 24),
      // Unreachable: the "none" branch is handled before this is called.
      DecayModel.none => Duration.zero,
    };
  }

  /// Generate the active-amount curve using the trackable's decay model.
  /// Same calls the dashboard decay card uses, just over a 30-day window.
  List<({DateTime time, double amount})> _generateCurve({
    required List<DoseLog> doses,
    required Trackable trackable,
    required DecayModel model,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    return switch (model) {
      DecayModel.exponential => DecayCalculator.generateCurve(
        doses: doses,
        halfLifeHours: trackable.halfLifeHours!,
        startTime: startTime,
        endTime: endTime,
        absorptionMinutes: trackable.absorptionMinutes,
      ),
      DecayModel.linear => DecayCalculator.generateLinearCurve(
        doses: doses,
        eliminationRate: trackable.eliminationRate!,
        startTime: startTime,
        endTime: endTime,
        absorptionMinutes: trackable.absorptionMinutes,
      ),
      DecayModel.none => const [],
    };
  }

  Widget _buildChart(
    BuildContext context, {
    required List<FlSpot> spots,
    required Color trackableColor,
    required String trackableUnit,
    required DateTime startBoundary,
    required DateTime todayBoundary,
    required double average,
  }) {
    final axisColor = Theme.of(context).colorScheme.onSurfaceVariant;

    final maxY = spots.fold<double>(0, (max, s) => s.y > max ? s.y : max);
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
          // Dotted horizontal line at the average peak across the days in view.
          horizontalLines: average > 0
              ? [
                  HorizontalLine(
                    y: average,
                    color: axisColor.withAlpha(120),
                    strokeWidth: 1,
                    dashArray: [2, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      style: TextStyle(
                        color: axisColor.withAlpha(180),
                        fontSize: 9,
                      ),
                      labelResolver: (_) =>
                          'avg ${formatWithSignificantDigits(average)}',
                    ),
                  ),
                ]
              : const [],
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
                  // Use significant digits so low peaks remain visible
                  // instead of being rounded down to 0 on chart labels.
                  formatWithSignificantDigits(value),
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
                final amountStr =
                    '${formatWithSignificantDigits(spot.y)} $trackableUnit';
                return LineTooltipItem(
                  '$dateStr\nPeak: $amountStr',
                  TextStyle(
                    color: trackableColor,
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
