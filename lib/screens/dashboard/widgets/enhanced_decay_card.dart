import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/data/decay_model.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/dashboard/taper_progress_screen.dart';
import 'package:taper/screens/dashboard/trackable_log_screen.dart';
import 'package:taper/screens/shared/quick_add_dose_dialog.dart';

/// Experimental dashboard card: same data as TrackableCard, but rendered with
/// sample12-style visuals: gradient area fill, pan & zoom, shadow glow,
/// and full-height touch indicator line.
///
/// Uses the same `trackableCardDataProvider` as TrackableCard for all data,
/// so results are always in sync. The only difference is the chart rendering.
///
/// Like a Livewire component with a different Blade template:
///   `<livewire:enhanced-decay-card :trackableId="$id" />`
class EnhancedDecayCard extends ConsumerWidget {
  final int trackableId;

  const EnhancedDecayCard({super.key, required this.trackableId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardDataAsync = ref.watch(trackableCardDataProvider(trackableId));

    return cardDataAsync.when(
      loading: () => _buildLoadingSkeleton(context),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $error'),
        ),
      ),
      data: (data) => _buildCard(context, ref, data),
    );
  }

  /// Builds the full card — identical layout to TrackableCard but with the
  /// enhanced chart replacing the standard DecayCurveChart.
  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    TrackableCardData data,
  ) {
    final trackable = data.trackable;
    final trackableColor = Color(trackable.color);
    final hasDecay =
        DecayModel.fromString(trackable.decayModel) != DecayModel.none;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        // Left border accent — same as TrackableCard.
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
              // Title row: name + stats (identical to TrackableCard).
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      trackable.name,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _buildStatsText(data),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              // Enhanced chart: sample12-style with pan/zoom, gradient, glow.
              // NOT wrapped in IgnorePointer — user can interact with the chart.
              if (hasDecay && data.curvePoints.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: _buildEnhancedChart(
                    context,
                    ref,
                    data: data,
                    trackableColor: trackableColor,
                  ),
                ),
              ],

              const SizedBox(height: 8),

              // Toolbar: identical to TrackableCard.
              Wrap(
                spacing: 8,
                children: [
                  if (data.lastDose != null)
                    TextButton.icon(
                      onPressed: () => _repeatLast(context, ref, data),
                      icon: const Icon(Icons.replay, size: 18),
                      label: const Text('Repeat Last'),
                    ),
                  TextButton.icon(
                    onPressed: () =>
                        _addDose(context, ref, data.trackable),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Dose'),
                  ),
                  TextButton.icon(
                    onPressed: () => _viewLog(context, trackable),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('View Log'),
                  ),
                  if (data.activeTaperPlan != null)
                    TextButton.icon(
                      onPressed: () => _viewProgress(context, data),
                      icon: const Icon(Icons.trending_down, size: 18),
                      label: const Text('Progress'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the sample12-style enhanced decay curve chart.
  ///
  /// Same data as DecayCurveChart but with:
  /// - Horizontal pan/zoom (FlTransformationConfig)
  /// - Gradient area fill (20% → 0% alpha)
  /// - Line shadow for glow effect
  /// - Full-height touch indicator line
  /// - Larger touch dot (radius 6)
  /// - Thinner line (barWidth 1) for a delicate sample12 look
  Widget _buildEnhancedChart(
    BuildContext context,
    WidgetRef ref, {
    required TrackableCardData data,
    required Color trackableColor,
  }) {
    final axisColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final chartStartTime = data.dayBoundaryTime;

    // Convert curve points to FlSpot(hours, amount) — same as DecayCurveChart.
    final spots = data.curvePoints.map((p) {
      final hoursFromStart =
          p.time.difference(chartStartTime).inMinutes / 60.0;
      return FlSpot(hoursFromStart, p.amount);
    }).toList();

    // Cumulative line spots (optional).
    final cumulativeSpots = data.cumulativePoints.map((p) {
      final hoursFromStart =
          p.time.difference(chartStartTime).inMinutes / 60.0;
      return FlSpot(hoursFromStart, p.amount);
    }).toList();

    // Max Y: include curve, cumulative, and threshold values.
    var maxY = spots.fold<double>(0, (max, s) => s.y > max ? s.y : max);
    for (final s in cumulativeSpots) {
      if (s.y > maxY) maxY = s.y;
    }
    for (final t in data.thresholds) {
      if (t.amount > maxY) maxY = t.amount;
    }
    if (data.taperTarget != null && data.taperTarget! > maxY) {
      maxY = data.taperTarget!;
    }
    final adjustedMaxY = maxY > 0 ? maxY * 1.1 : 1.0;
    final maxX = spots.last.x;

    // "Now" indicator position.
    final isLive = ref.watch(selectedDateProvider) == null;
    final double? clampedNowHours;
    if (isLive) {
      final now = DateTime.now();
      final nowHours = now.difference(chartStartTime).inMinutes / 60.0;
      clampedNowHours = nowHours.clamp(0.0, maxX);
    } else {
      clampedNowHours = null;
    }

    return LineChart(
      // Horizontal pan/zoom — the key sample12 feature.
      // maxScale 10 allows deep zooming into specific time ranges.
      transformationConfig: const FlTransformationConfig(
        scaleAxis: FlScaleAxis.horizontal,
        minScale: 1.0,
        maxScale: 10.0,
      ),
      LineChartData(
        clipData: const FlClipData.all(),
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: adjustedMaxY,

        lineBarsData: [
          // Primary: decay curve with gradient fill + shadow glow.
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: trackableColor,
            // Thinner line for sample12's delicate look.
            barWidth: 1,
            // Shadow behind the line creates a colored glow effect.
            shadow: Shadow(
              color: trackableColor.withAlpha(80),
              blurRadius: 4,
            ),
            dotData: const FlDotData(show: false),
            // Gradient area fill: trackable color from 20% → 0% alpha.
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
          // Secondary: cumulative intake staircase (same as DecayCurveChart).
          if (cumulativeSpots.isNotEmpty)
            LineChartBarData(
              spots: cumulativeSpots,
              isCurved: false,
              color: trackableColor.withAlpha(120),
              barWidth: 1,
              dotData: const FlDotData(show: false),
              dashArray: [6, 4],
              belowBarData: BarAreaData(show: false),
            ),
        ],

        // Vertical "now" line + threshold horizontal lines.
        extraLinesData: ExtraLinesData(
          verticalLines: [
            if (clampedNowHours != null)
              VerticalLine(
                x: clampedNowHours,
                color: axisColor.withAlpha(100),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
          ],
          horizontalLines: [
            // Threshold lines (e.g., "Daily max" at 400 mg).
            for (final t in data.thresholds)
              HorizontalLine(
                y: t.amount,
                color: axisColor.withAlpha(120),
                strokeWidth: 1,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 4, bottom: 2),
                  style: TextStyle(
                    color: axisColor.withAlpha(180),
                    fontSize: 9,
                  ),
                  labelResolver: (_) => t.name,
                ),
              ),
            // Taper target line (if active plan exists).
            if (data.taperTarget != null)
              HorizontalLine(
                y: data.taperTarget!,
                color: axisColor.withAlpha(120),
                strokeWidth: 1,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 4, bottom: 2),
                  style: TextStyle(
                    color: axisColor.withAlpha(180),
                    fontSize: 9,
                  ),
                  labelResolver: (_) => 'Target',
                ),
              ),
          ],
        ),

        // Axis labels — same style as DecayCurveChart.
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 4,
              getTitlesWidget: (value, meta) {
                final time = chartStartTime.add(
                  Duration(minutes: (value * 60).round()),
                );
                return Text(
                  time.hour.toString().padLeft(2, '0'),
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
              reservedSize: 36,
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

        // Touch handling: full-height indicator + tooltip (sample12 style).
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          // Full-height vertical indicator line.
          getTouchLineStart: (barData, spotIndex) => -double.infinity,
          getTouchLineEnd: (barData, spotIndex) => double.infinity,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                Theme.of(context).colorScheme.surfaceContainerHighest,
            getTooltipItems: (spots) {
              // Label lines "Active" and "Total" when cumulative is shown.
              final hasTwo =
                  cumulativeSpots.isNotEmpty && spots.length == 2;
              final labels = hasTwo ? ['Active', 'Total'] : [null];
              return spots.asMap().entries.map((entry) {
                final index = entry.key;
                final spot = entry.value;
                final spotTime = chartStartTime.add(
                  Duration(minutes: (spot.x * 60).round()),
                );
                final timeStr =
                    '${spotTime.hour.toString().padLeft(2, '0')}:${spotTime.minute.toString().padLeft(2, '0')}';
                final label =
                    index < labels.length ? labels[index] : null;
                final valueStr = label != null
                    ? '$label: ${spot.y.toStringAsFixed(1)}'
                    : spot.y.toStringAsFixed(1);
                final text =
                    index == 0 ? '$valueStr\n$timeStr' : valueStr;
                return LineTooltipItem(
                  text,
                  TextStyle(
                    color: spot.bar.color ?? trackableColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
          // Larger dot at touch point (radius 6) vs. DecayCurveChart's 4.
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

  /// Stats text: same format as TrackableCard._buildStatsText.
  String _buildStatsText(TrackableCardData data) {
    final unit = data.trackable.unit;
    final totalStr = data.totalToday.toStringAsFixed(0);
    final hasDecay =
        DecayModel.fromString(data.trackable.decayModel) != DecayModel.none;

    String base;
    if (hasDecay) {
      final activeStr = data.activeAmount.toStringAsFixed(0);
      base = '$activeStr / $totalStr $unit';
    } else {
      base = '$totalStr $unit';
    }

    if (data.taperTarget != null) {
      base += ' (target: ${data.taperTarget!.toStringAsFixed(0)})';
    }

    return base;
  }

  // --- Toolbar actions: identical to TrackableCard ---

  void _repeatLast(
    BuildContext context,
    WidgetRef ref,
    TrackableCardData data,
  ) async {
    final lastDose = data.lastDose!;
    final db = ref.read(databaseProvider);

    final insertedId = await db.insertDoseLog(
      lastDose.trackableId,
      lastDose.amount,
      DateTime.now(),
      name: lastDose.name,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          showCloseIcon: true,
          content: Text(
            'Logged ${lastDose.amount.toStringAsFixed(0)} ${data.trackable.unit} ${data.trackable.name}',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => db.deleteDoseLog(insertedId),
          ),
        ),
      );
    }
  }

  void _addDose(
    BuildContext context,
    WidgetRef ref,
    Trackable trackable,
  ) async {
    final db = ref.read(databaseProvider);
    final presetsList = await db.getPresets(trackable.id);
    if (!context.mounted) return;
    showQuickAddDoseDialog(
      context: context,
      trackable: trackable,
      db: db,
      presets: presetsList,
    );
  }

  void _viewLog(BuildContext context, Trackable trackable) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackableLogScreen(trackable: trackable),
      ),
    );
  }

  void _viewProgress(BuildContext context, TrackableCardData data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaperProgressScreen(
          trackable: data.trackable,
          taperPlan: data.activeTaperPlan!,
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
}
