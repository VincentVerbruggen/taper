import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/dashboard/trackable_log_screen.dart';
import 'package:taper/utils/day_boundary.dart';
import 'package:taper/utils/taper_calculator.dart';

/// Dashboard card showing daily intake totals over the past 30 days.
///
/// Renders a line/area chart with sample12-style visuals: gradient fill,
/// horizontal pan/zoom, shadow glow, and full-height touch indicator line.
///
/// Default view: zoomed in to the last 7 days. The user can scroll left to
/// see older data, or pinch to zoom in/out (1x = all 30 days, 15x = 2 days).
/// Like Google Finance charts where you see a week by default but can scroll.
///
/// ConsumerStatefulWidget because we need a TransformationController to set
/// the initial zoom level (show last 7 of 30 days on first render).
class DailyTotalsCard extends ConsumerStatefulWidget {
  final int trackableId;

  const DailyTotalsCard({super.key, required this.trackableId});

  @override
  ConsumerState<DailyTotalsCard> createState() => _DailyTotalsCardState();
}

class _DailyTotalsCardState extends ConsumerState<DailyTotalsCard> {
  /// Controls the chart's zoom/pan transform. We own this controller so we
  /// can set an initial zoom showing the last 7 days (instead of all 30).
  /// Like setting `initialScrollOffset` on a ScrollController.
  late TransformationController _chartController;

  /// GlobalKey on the chart SizedBox — used to measure the chart's pixel width
  /// so we can calculate the correct initial zoom transform.
  final _chartSizeKey = GlobalKey();

  /// Guard to only apply the initial zoom once (on first layout).
  /// Without this, every rebuild would reset the user's scroll position.
  bool _initialZoomApplied = false;

  /// How many of the 30 total days to show in the default viewport.
  /// 7 = one week visible, user scrolls left for history.
  static const _defaultVisibleDays = 7;

  /// Total days of data loaded.
  static const _totalDays = 30;

  @override
  void initState() {
    super.initState();
    _chartController = TransformationController();
  }

  @override
  void dispose() {
    _chartController.dispose();
    super.dispose();
  }

  /// Applies the initial zoom/pan to show the last 7 of 30 days.
  ///
  /// Called via addPostFrameCallback after the chart renders for the first time.
  /// We need the chart's actual pixel width to calculate the correct translateX.
  ///
  /// The TransformationController matrix maps child → viewport coordinates:
  ///   viewportX = scaleX * childX + translateX
  ///
  /// To show the rightmost 7/30 of the chart:
  ///   scaleX = 30/7 ≈ 4.286 (zoom in so 7 days fill the viewport)
  ///   translateX = -(scaleX - 1) * chartInnerWidth (scroll to the right end)
  ///
  /// The "chartInnerWidth" is the chart area excluding axis titles. fl_chart's
  /// scaffold applies a margin for the left axis (reservedSize=40), so the
  /// inner width = measured SizedBox width - 40.
  void _applyInitialZoom() {
    if (_initialZoomApplied) return;

    final box =
        _chartSizeKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    // The SizedBox includes the left axis title area (40px reservedSize).
    // The TransformationController operates on the inner chart area only.
    const leftAxisReservedSize = 40.0;
    final chartInnerWidth = box.size.width - leftAxisReservedSize;
    if (chartInnerWidth <= 0) return;

    final scale = _totalDays / _defaultVisibleDays;
    // Negative translateX scrolls the viewport to the right (showing later days).
    final tx = -(scale - 1.0) * chartInnerWidth;

    // Set the matrix directly: [scaleX, 0, 0, tx; 0, 1, 0, 0; ...]
    // Using setEntry avoids matrix multiplication order confusion.
    _chartController.value = Matrix4.identity()
      ..setEntry(0, 0, scale) // scaleX = 30/7
      ..setEntry(0, 3, tx); // translateX = scroll to right end

    _initialZoomApplied = true;
  }

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
        final now = DateTime.now();
        final todayBoundary = dayBoundary(now, boundaryHour: boundaryHour);

        // Date range: 30 days back from today's day boundary.
        final startBoundary = DateTime(
          todayBoundary.year,
          todayBoundary.month,
          todayBoundary.day - (_totalDays - 1),
          todayBoundary.hour,
        );
        // End = next day boundary (so we include all of today's doses).
        final endBoundary =
            nextDayBoundary(now, boundaryHour: boundaryHour);

        return GestureDetector(
          // Tap the title area to navigate to the full log.
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrackableLogScreen(trackable: trackable),
            ),
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Container(
              // Left border accent in the trackable's color.
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
                    // Title row: "{Name} — Daily Totals" + "30 days".
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            '${trackable.name} — Daily Totals',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '30 days',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // StreamBuilder: reactively update when doses change.
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
                            padding:
                                const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'No doses in the last 30 days.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          );
                        }

                        // Convert to DoseLogLike for TaperCalculator.
                        final adapters = doses
                            .map((d) => _DoseLogAdapter(d))
                            .toList();

                        // Group by day boundary and sum amounts.
                        final dailyTotals = TaperCalculator.dailyTotals(
                          doses: adapters,
                          boundaryHour: boundaryHour,
                        );

                        // Build FlSpots: one per day (0..29), Y = daily total.
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

                        // Average over all 30 days for a true daily average.
                        final daysWithData = dailyTotals.values
                            .where((v) => v > 0)
                            .length;
                        final avg = totalSum / _totalDays;

                        // Schedule the initial zoom after the chart renders.
                        // addPostFrameCallback ensures the RenderBox exists
                        // and has been laid out before we try to measure it.
                        if (!_initialZoomApplied) {
                          SchedulerBinding.instance
                              .addPostFrameCallback((_) {
                            if (mounted) _applyInitialZoom();
                          });
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Subtitle: average daily intake.
                            Text(
                              'avg: ${avg.toStringAsFixed(0)} ${trackable.unit}/day'
                              '${daysWithData < _totalDays ? ' ($daysWithData days with doses)' : ''}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Chart: 200px, sample12-style with pan/zoom.
                            // Key on the SizedBox to measure width for initial zoom.
                            // NOT wrapped in IgnorePointer — user can pan/zoom/scrub.
                            SizedBox(
                              key: _chartSizeKey,
                              height: 200,
                              child: _buildChart(
                                context,
                                spots: spots,
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

  /// Builds the sample12-style line chart for daily totals.
  ///
  /// Features:
  /// - Gradient area fill (trackable color, 20% → 0% alpha)
  /// - Line shadow for glow effect
  /// - Horizontal pan/zoom via FlTransformationConfig with our controller
  /// - Full-height vertical touch indicator line
  /// - Touch tooltip with date + amount
  /// - Small dots at every data point
  /// - "Today" vertical dashed line
  Widget _buildChart(
    BuildContext context, {
    required List<FlSpot> spots,
    required Color trackableColor,
    required String trackableUnit,
    required DateTime startBoundary,
    required DateTime todayBoundary,
  }) {
    final axisColor = Theme.of(context).colorScheme.onSurfaceVariant;

    // Max Y for scaling: highest value + 10% headroom.
    var maxY = spots.fold<double>(0, (max, s) => s.y > max ? s.y : max);
    final adjustedMaxY = maxY > 0 ? maxY * 1.1 : 1.0;

    // "Today" vertical line position (days from start boundary).
    final todayX = todayBoundary
        .difference(startBoundary)
        .inDays
        .toDouble()
        .clamp(0.0, (_totalDays - 1).toDouble());

    return LineChart(
      // Horizontal pan/zoom with our controller that starts zoomed to last 7 days.
      // maxScale = 15: from 7-day default, user can zoom in to ~2 days visible.
      // minScale = 1: user can zoom out to see all 30 days.
      transformationConfig: FlTransformationConfig(
        scaleAxis: FlScaleAxis.horizontal,
        minScale: 1.0,
        maxScale: 15.0,
        transformationController: _chartController,
      ),
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
            // Shadow for glow effect (sample12 style).
            shadow: Shadow(
              color: trackableColor.withAlpha(80),
              blurRadius: 4,
            ),
            // Small dots at every data point.
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
            // Gradient area fill: 20% alpha → transparent.
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

        // "Today" vertical dashed line.
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

        // Axis labels.
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
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),

        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),

        // Touch tooltip: date + amount. Full-height indicator line.
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
                    '${spot.y.toStringAsFixed(0)} $trackableUnit';
                return LineTooltipItem(
                  '$dateStr\n$amountStr',
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
                      color: trackableColor,
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

  /// Loading skeleton matching the card pattern.
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

/// Adapter bridging Drift's DoseLog to TaperCalculator's DoseLogLike interface.
/// Same pattern as TaperProgressCard's _DoseLogAdapter.
class _DoseLogAdapter implements DoseLogLike {
  final DoseLog _doseLog;
  _DoseLogAdapter(this._doseLog);

  @override
  double get amount => _doseLog.amount;

  @override
  DateTime get loggedAt => _doseLog.loggedAt;
}
