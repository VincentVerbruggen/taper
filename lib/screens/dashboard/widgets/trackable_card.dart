import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/data/decay_model.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/dashboard/taper_progress_screen.dart';
import 'package:taper/screens/dashboard/trackable_log_screen.dart';
import 'package:taper/screens/shared/quick_add_dose_dialog.dart';
import 'package:taper/utils/decay_calculator.dart';

/// Chart viewing mode for the trackable card.
enum ChartMode {
  decay,
  total;

  static ChartMode fromConfig(String configJson) {
    try {
      final map = jsonDecode(configJson) as Map<String, dynamic>;
      return map['mode'] == 'total' ? ChartMode.total : ChartMode.decay;
    } catch (_) {
      return ChartMode.decay;
    }
  }
}

class TrackableCard extends ConsumerStatefulWidget {
  final int trackableId;
  final int? widgetId;
  final String config;

  const TrackableCard({
    super.key,
    required this.trackableId,
    this.widgetId,
    this.config = '{}',
  });

  @override
  ConsumerState<TrackableCard> createState() => _TrackableCardState();
}

class _TrackableCardState extends ConsumerState<TrackableCard> {
  @override
  Widget build(BuildContext context) {
    final cardDataAsync = ref.watch(
      trackableCardDataProvider(widget.trackableId),
    );

    return cardDataAsync.when(
      loading: () => _buildLoadingSkeleton(context),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $error'),
        ),
      ),
      data: (data) => _buildCard(context, data),
    );
  }

  Widget _buildCard(BuildContext context, TrackableCardData data) {
    final trackable = data.trackable;
    final trackableColor = Color(trackable.color);
    final hasDecay =
        DecayModel.fromString(trackable.decayModel) != DecayModel.none;
    final mode = ChartMode.fromConfig(widget.config);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          trackable.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _buildStatsText(data, mode),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasDecay && data.cumulativePoints.isNotEmpty)
                  _buildModeToggle(context, mode),
                _buildOverflowMenu(context, data),
              ],
            ),

            if (hasDecay && data.curvePoints.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: _buildDualModeChart(
                  context,
                  data: data,
                  trackableColor: trackableColor,
                  mode: mode,
                ),
              ),
            ],

            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              children: [
                if (data.lastDose != null)
                  TextButton.icon(
                    onPressed: () => _repeatLast(context, data),
                    icon: const Icon(Icons.replay, size: 18),
                    label: const Text('Repeat Last'),
                  ),
                TextButton.icon(
                  onPressed: () => _addDose(context, data.trackable),
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
    );
  }

  Widget _buildModeToggle(BuildContext context, ChartMode mode) {
    return IconButton(
      icon: Icon(
        mode == ChartMode.decay ? Icons.show_chart : Icons.bar_chart,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      tooltip: mode == ChartMode.decay
          ? 'Switch to total view'
          : 'Switch to decay view',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () {
        if (widget.widgetId == null) return;
        final newMode = mode == ChartMode.decay ? 'total' : 'decay';
        Map<String, dynamic> configMap;
        try {
          configMap = jsonDecode(widget.config) as Map<String, dynamic>;
        } catch (_) {
          configMap = {};
        }
        configMap['mode'] = newMode;
        ref
            .read(databaseProvider)
            .updateDashboardWidgetConfig(
              widget.widgetId!,
              jsonEncode(configMap),
            );
      },
    );
  }

  Widget _buildDualModeChart(
    BuildContext context, {
    required TrackableCardData data,
    required Color trackableColor,
    required ChartMode mode,
  }) {
    final axisColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final chartStartTime = data.dayBoundaryTime;
    // Targets are "active amount at a specific clock time", so they belong on
    // the decay view. We intentionally keep total mode focused on cumulative
    // intake + optional daily-total thresholds.
    final showTargets = mode == ChartMode.decay;

    final decaySpots = data.curvePoints.map((p) {
      final hoursFromStart = p.time.difference(chartStartTime).inMinutes / 60.0;
      return FlSpot(hoursFromStart, p.amount);
    }).toList();

    final cumulativeSpots = data.cumulativePoints.map((p) {
      final hoursFromStart = p.time.difference(chartStartTime).inMinutes / 60.0;
      return FlSpot(hoursFromStart, p.amount);
    }).toList();

    double maxY;
    if (mode == ChartMode.total && cumulativeSpots.isNotEmpty) {
      maxY = cumulativeSpots.fold<double>(0, (max, s) => s.y > max ? s.y : max);
      for (final s in decaySpots) {
        if (s.y > maxY) maxY = s.y;
      }
    } else {
      maxY = decaySpots.fold<double>(0, (max, s) => s.y > max ? s.y : max);
      for (final s in cumulativeSpots) {
        if (s.y > maxY) maxY = s.y;
      }
    }

    final relevantComparisonType = mode == ChartMode.decay
        ? 'active_amount'
        : 'daily_total';
    final visibleThresholds = data.thresholds
        .where((t) => t.comparisonType == relevantComparisonType)
        .toList();

    final minX = decaySpots.first.x;
    final maxX = decaySpots.last.x;

    final targetSpots = showTargets
        ? data.targets
              .map(
                (target) => _targetToChartSpot(
                  target: target,
                  chartStartTime: chartStartTime,
                  minX: minX,
                  maxX: maxX,
                ),
              )
              .whereType<FlSpot>()
              .toList()
        : <FlSpot>[];

    // Include only the things we actually render in current mode.
    for (final threshold in visibleThresholds) {
      if (threshold.amount > maxY) maxY = threshold.amount;
    }
    if (showTargets) {
      for (final spot in targetSpots) {
        if (spot.y > maxY) maxY = spot.y;
      }
    }
    final adjustedVisibleMaxY = maxY > 0 ? maxY * 1.1 : 1.0;

    final lineBars = <LineChartBarData>[];
    if (mode == ChartMode.decay) {
      lineBars.add(
        _buildPrimaryLine(decaySpots, trackableColor, isCurved: true),
      );
      if (cumulativeSpots.isNotEmpty) {
        lineBars.add(
          _buildSecondaryLine(cumulativeSpots, trackableColor, isCurved: false),
        );
      }
    } else {
      if (cumulativeSpots.isNotEmpty) {
        lineBars.add(
          _buildPrimaryLine(cumulativeSpots, trackableColor, isCurved: false),
        );
      }
      lineBars.add(
        _buildSecondaryLine(decaySpots, trackableColor, isCurved: true),
      );
    }

    // Draw targets as dots (no connecting line). This keeps the chart readable
    // while still making target events visible in decay mode.
    int? targetBarIndex;
    if (showTargets && targetSpots.isNotEmpty) {
      lineBars.add(_buildTargetPointsLine(targetSpots, axisColor));
      targetBarIndex = lineBars.length - 1;
    }

    final thresholdLines = visibleThresholds
        .map(
          (threshold) => HorizontalLine(
            y: threshold.amount,
            color: axisColor.withAlpha(120),
            strokeWidth: 1,
            dashArray: [6, 4],
          ),
        )
        .toList();

    return LineChart(
      LineChartData(
        clipData: const FlClipData.all(),
        minX: minX,
        maxX: maxX,
        minY: 0,
        maxY: adjustedVisibleMaxY,
        lineBarsData: lineBars,
        // Thresholds are horizontal guide lines (active-amount in decay mode,
        // daily-total in total mode), matching the selected chart context.
        extraLinesData: ExtraLinesData(horizontalLines: thresholdLines),
        // Explicitly disable the default grid/border lines from fl_chart.
        // Without this, fl_chart auto-generates a full grid that adds visual
        // noise on top of the decay/total series.
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        // Match the totals chart axis style: bottom time labels + left Y labels.
        // Right/top remain hidden to avoid duplicate information.
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              // Use 1h sampling, then filter in getTitlesWidget.
              //
              // Why: the chart X-axis is "hours since day boundary" (usually 05:00),
              // but users read the axis as wall-clock time. A fixed 6h interval from
              // the boundary (05, 11, 17, 23...) feels shifted. Sampling hourly and
              // only rendering labels at real clock anchors (00, 06, 12, 18) keeps
              // numbering intuitive regardless of the configured day boundary.
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value < minX || value > maxX) {
                  return const SizedBox.shrink();
                }
                final labelTime = _timeFromChartX(chartStartTime, value);
                if (!_shouldShowBottomHourLabel(labelTime)) {
                  return const SizedBox.shrink();
                }
                return Text(
                  _formatHourLabel(labelTime),
                  style: TextStyle(
                    color: axisColor.withAlpha(170),
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
        // Replace generic numeric tooltips with clock time + amount, so the
        // touched point reflects the same hour labels the user sees on the axis.
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                Theme.of(context).colorScheme.surfaceContainerHighest,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final spotTime = _timeFromChartX(chartStartTime, spot.x);
                final timeStr =
                    '${spotTime.hour.toString().padLeft(2, '0')}:${spotTime.minute.toString().padLeft(2, '0')}';
                final amount = spot.y.toStringAsFixed(0);
                final isTargetSpot =
                    targetBarIndex != null && spot.barIndex == targetBarIndex;
                final label = isTargetSpot ? 'Target' : 'Amount';
                return LineTooltipItem(
                  '$timeStr\n$label: $amount ${data.trackable.unit}',
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
        ),
      ),
    );
  }

  /// Convert chart-space X (hours from start) back into a real DateTime.
  ///
  /// We round to whole minutes so labels/tooltips stay stable and readable
  /// even if fl_chart gives us fractional X values while panning/touching.
  DateTime _timeFromChartX(DateTime chartStartTime, double chartX) {
    return chartStartTime.add(Duration(minutes: (chartX * 60).round()));
  }

  /// Bottom-axis label formatter for the decay chart.
  ///
  /// Uses fixed 24h clock style to avoid locale AM/PM variations in charts.
  String _formatHourLabel(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:00';
  }

  /// Parse a stored target ("HH:mm") and convert it to chart-space X.
  ///
  /// Returns null for malformed/out-of-range times so one bad row doesn't break
  /// chart rendering.
  FlSpot? _targetToChartSpot({
    required Target target,
    required DateTime chartStartTime,
    required double minX,
    required double maxX,
  }) {
    final timeParts = target.time.split(':');
    if (timeParts.length != 2) return null;
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    final targetTime = DateTime(
      chartStartTime.year,
      chartStartTime.month,
      chartStartTime.day,
      hour,
      minute,
    );

    final adjustedTargetTime = targetTime.isBefore(chartStartTime)
        ? targetTime.add(const Duration(days: 1))
        : targetTime;
    final hoursFromStart =
        adjustedTargetTime.difference(chartStartTime).inMinutes / 60.0;

    if (hoursFromStart < minX || hoursFromStart > maxX) return null;
    return FlSpot(hoursFromStart, target.amount);
  }

  /// True when this timestamp should be shown on the bottom axis.
  ///
  /// We keep labels sparse and familiar by only showing midnight/noon-style
  /// anchors every 6 hours (00, 06, 12, 18).
  bool _shouldShowBottomHourLabel(DateTime time) {
    return time.minute == 0 && time.hour % 6 == 0;
  }

  /// Render targets as emphasized dots without connecting segments.
  ///
  /// Think of these like "milestone markers" on top of the decay curve.
  LineChartBarData _buildTargetPointsLine(List<FlSpot> spots, Color axisColor) {
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      // 0-width hides the connecting polyline; only dots remain visible.
      barWidth: 0,
      color: axisColor.withAlpha(220),
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) {
          return FlDotCirclePainter(
            radius: 3.5,
            color: axisColor.withAlpha(220),
            strokeWidth: 1.2,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(show: false),
    );
  }

  LineChartBarData _buildPrimaryLine(
    List<FlSpot> spots,
    Color color, {
    required bool isCurved,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: isCurved,
      curveSmoothness: isCurved ? 0.35 : 0,
      color: color,
      barWidth: 1,
      shadow: Shadow(color: color.withAlpha(80), blurRadius: 4),
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withAlpha(50), color.withAlpha(0)],
        ),
      ),
    );
  }

  LineChartBarData _buildSecondaryLine(
    List<FlSpot> spots,
    Color color, {
    required bool isCurved,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: isCurved,
      curveSmoothness: isCurved ? 0.35 : 0,
      color: color.withAlpha(120),
      barWidth: 1,
      dotData: const FlDotData(show: false),
      dashArray: [6, 4],
      belowBarData: BarAreaData(show: false),
    );
  }

  Widget _buildOverflowMenu(BuildContext context, TrackableCardData data) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      tooltip: 'More actions',
      padding: EdgeInsets.zero,
      onSelected: (value) {
        switch (value) {
          case 'repeat':
            _repeatLast(context, data);
          case 'add':
            _addDose(context, data.trackable);
          case 'log':
            _viewLog(context, data.trackable);
          case 'progress':
            _viewProgress(context, data);
        }
      },
      itemBuilder: (context) => [
        if (data.lastDose != null)
          const PopupMenuItem(
            value: 'repeat',
            child: ListTile(
              leading: Icon(Icons.replay),
              title: Text('Repeat Last'),
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuItem(
          value: 'add',
          child: ListTile(
            leading: Icon(Icons.add),
            title: Text('Add Dose'),
            visualDensity: VisualDensity.compact,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'log',
          child: ListTile(
            leading: Icon(Icons.history),
            title: Text('View Log'),
            visualDensity: VisualDensity.compact,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (data.activeTaperPlan != null)
          const PopupMenuItem(
            value: 'progress',
            child: ListTile(
              leading: Icon(Icons.trending_down),
              title: Text('Progress'),
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  String _buildStatsText(TrackableCardData data, ChartMode mode) {
    final unit = data.trackable.unit;
    final totalStr = data.totalToday.toStringAsFixed(0);
    final hasDecay =
        DecayModel.fromString(data.trackable.decayModel) != DecayModel.none;

    String base;
    if (!hasDecay) {
      base = '$totalStr $unit';
    } else if (mode == ChartMode.total) {
      base = '$totalStr $unit today';
    } else {
      final activeStr = data.activeAmount.toStringAsFixed(0);
      base = '$activeStr / $totalStr $unit';
    }

    if (data.taperTarget != null) {
      base += ' (target: ${data.taperTarget!.toStringAsFixed(0)})';
    }

    return base;
  }

  void _repeatLast(BuildContext context, TrackableCardData data) async {
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

  void _addDose(BuildContext context, Trackable trackable) async {
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
