import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Mini decay curve chart displayed inside each trackable card.
///
/// Shows the rise and fall of active amount throughout the day.
/// Uses fl_chart's LineChart (similar to Chart.js in the web world):
///   - Single curved line in the trackable's color
///   - Translucent fill below the line
///   - Dashed vertical line at "now" position
///   - Bottom axis with clock time labels (5a, 9a, 1p, ...)
///   - Left axis with amount labels
///   - Touch scrubbing with tooltip showing amount + time
class DecayCurveChart extends StatelessWidget {
  /// The decay curve data points from DecayCalculator.generateCurve().
  final List<({DateTime time, double amount})> curvePoints;

  /// The trackable's color (ARGB int from the palette).
  final Color color;

  /// The start time of the chart (day boundary), used for X-axis time labels.
  /// If not provided, falls back to the first curve point's time.
  final DateTime? startTime;

  /// Whether the chart is showing live (today) data.
  /// When false (viewing a past date), the "now" vertical indicator is hidden.
  final bool isLive;

  /// Fixed height for the chart. Slightly taller than before to fit axis labels.
  final double height;

  const DecayCurveChart({
    super.key,
    required this.curvePoints,
    required this.color,
    this.startTime,
    this.isLive = true,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    if (curvePoints.isEmpty) return const SizedBox.shrink();

    // The reference start time for the X axis. This is the day boundary
    // (e.g., 5:00 AM), so X=0 maps to that time.
    final chartStartTime = startTime ?? curvePoints.first.time;

    // Convert curve points to FlSpot(x, y) for fl_chart.
    // X axis = hours from the start of the curve (day boundary).
    // Y axis = active amount in the trackable's unit.
    final spots = curvePoints.map((p) {
      final hoursFromStart =
          p.time.difference(chartStartTime).inMinutes / 60.0;
      return FlSpot(hoursFromStart, p.amount);
    }).toList();

    // Find the max Y value for chart scaling. Add 10% headroom so the
    // peak doesn't touch the top edge.
    final maxY = spots.fold<double>(0, (max, s) => s.y > max ? s.y : max);
    final adjustedMaxY = maxY > 0 ? maxY * 1.1 : 1.0;

    final maxX = spots.last.x;

    // Calculate "now" position on the X axis for the vertical indicator line.
    // Only used when showing live data (today).
    final double? clampedNowHours;
    if (isLive) {
      final now = DateTime.now();
      final nowHours = now.difference(chartStartTime).inMinutes / 60.0;
      clampedNowHours = nowHours.clamp(0.0, maxX);
    } else {
      clampedNowHours = null;
    }

    // Theme colors for axis labels and grid.
    final axisColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          clipData: const FlClipData.all(),
          minX: 0,
          maxX: maxX,
          minY: 0,
          maxY: adjustedMaxY,

          // --- The decay curve line ---
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              // Higher smoothness reduces jagged jumps when a new dose is added.
              // 0.35 produces a smooth curve without losing the shape of the data.
              curveSmoothness: 0.35,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withAlpha(40),
              ),
            ),
          ],

          // --- Dashed vertical "now" line (only in live mode) ---
          // Hidden when viewing past dates since "now" isn't on the chart.
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
          ),

          // --- Axis labels ---
          // Bottom: clock times every 4 hours from the day boundary.
          // Left: auto-scaled amount labels (2-3 values).
          // Like Chart.js scales config.
          titlesData: FlTitlesData(
            // Bottom axis: show time labels at 4-hour intervals.
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                // Show a label every 4 hours (0, 4, 8, 12, 16, 20, 24).
                interval: 4,
                getTitlesWidget: (value, meta) {
                  return _buildTimeLabel(value, chartStartTime, axisColor);
                },
              ),
            ),
            // Left axis: amount labels, auto-spaced by fl_chart.
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                // Let fl_chart pick the interval; just show 2-3 labels.
                getTitlesWidget: (value, meta) {
                  // Skip min/max edge labels to avoid overlap with chart border.
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
            // Hide top and right axes — they just add noise on a mini chart.
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),

          // No border or grid — keeps the chart clean.
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),

          // --- Touch scrubbing / tooltip ---
          // Shows the amount and time at the touched position.
          // Like Chart.js tooltip plugin with mode: 'index'.
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) =>
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  // Convert X (hours from start) back to clock time.
                  final spotTime = chartStartTime.add(
                    Duration(minutes: (spot.x * 60).round()),
                  );
                  final hour = spotTime.hour;
                  final minute = spotTime.minute;
                  // 24h NATO format: "14:30" instead of "2:30 PM".
                  final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)}\n$timeStr',
                    TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
            // Vertical line + dot at the touch point.
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
                    getDotPainter: (spot, percent, bar, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: color,
                        strokeWidth: 1,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  /// Builds a time label for the bottom axis at a given X position (hours from start).
  /// Converts hours offset back to a clock time and formats in 24h NATO: "05", "09", "13", etc.
  Widget _buildTimeLabel(double hoursFromStart, DateTime start, Color labelColor) {
    // Convert the X value (hours from day boundary) to a DateTime.
    final time = start.add(Duration(minutes: (hoursFromStart * 60).round()));
    final hour = time.hour;

    // 24h format: just the hour with leading zero ("05", "09", "13", "17", "21", "01").
    return Text(
      hour.toString().padLeft(2, '0'),
      style: TextStyle(
        color: labelColor.withAlpha(150),
        fontSize: 10,
      ),
    );
  }
}
