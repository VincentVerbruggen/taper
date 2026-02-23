import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/data/decay_model.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/dashboard/taper_progress_screen.dart';
import 'package:taper/screens/dashboard/trackable_log_screen.dart';
import 'package:taper/screens/shared/quick_add_dose_dialog.dart';

/// Chart viewing mode for the trackable card.
///
/// Like a PHP enum: enum ChartMode: string { case Decay = 'decay'; case Total = 'total'; }
enum ChartMode {
  /// Decay focus: primary line = active amount curve, secondary = cumulative dashed.
  /// Y-axis scales to max active amount. Stats show "42 / 180 mg".
  decay,

  /// Total focus: primary line = cumulative staircase, secondary = decay dashed.
  /// Y-axis scales to max cumulative amount. Stats show "180 mg today".
  total;

  /// Parse from config JSON string. Returns decay as default.
  static ChartMode fromConfig(String configJson) {
    try {
      final map = jsonDecode(configJson) as Map<String, dynamic>;
      return map['mode'] == 'total' ? ChartMode.total : ChartMode.decay;
    } catch (_) {
      return ChartMode.decay;
    }
  }
}

/// Dashboard card showing a trackable's current status with enhanced visuals.
///
/// Features:
///   - Dual-mode chart (decay focus / total focus) with toggle
///   - Multi-day view: shows 6h carry-over from yesterday and 6h projection into tomorrow
///   - Pan/zoom enabled, default viewport focuses on today's 24h period
///   - Day boundary markers at today's start and end
///
/// ConsumerStatefulWidget because it manages a TransformationController
/// for the chart's initial viewport (scroll to show today's period).
class TrackableCard extends ConsumerStatefulWidget {
  final int trackableId;

  /// The dashboard widget's DB row ID — needed to persist config changes.
  /// Null in tests where the card is rendered standalone.
  final int? widgetId;

  /// The dashboard widget's config JSON string from the DB.
  /// Contains {"mode": "decay"} or {"mode": "total"}.
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
  /// Controls the chart's initial pan position so the viewport starts on
  /// today's 24h period, with yesterday's carry-over scrollable to the left.
  /// Like a ScrollController for a horizontally scrollable chart.
  final _chartController = TransformationController();

  /// Key for the chart's SizedBox — used to measure pixel width for
  /// calculating the initial viewport offset.
  final _chartKey = GlobalKey();

  /// Prevents re-applying the initial zoom on every rebuild.
  bool _initialZoomApplied = false;

  @override
  void dispose() {
    _chartController.dispose();
    super.dispose();
  }

  /// Applies the initial viewport position after the first frame renders.
  ///
  /// The chart data spans ~36h (-6h to +30h from day boundary), but the
  /// default view should show today's 24h period (0h to 24h). We calculate
  /// a horizontal scale and translate to achieve this.
  ///
  /// Same pattern as DailyTotalsCard: measure RenderBox width post-frame,
  /// then set the TransformationController's Matrix4.
  void _applyInitialZoom(double totalHours) {
    if (_initialZoomApplied) return;
    _initialZoomApplied = true;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      final renderBox =
          _chartKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;

      // Chart inner width = total width - left axis reserved space (36px).
      final chartInnerWidth = renderBox.size.width - 36;
      if (chartInnerWidth <= 0) return;

      // Scale so 24h fills the viewport (out of ~36h total).
      // E.g., 36h / 24h = 1.5x scale.
      const visibleHours = 24.0;
      final scale = totalHours / visibleHours;
      if (scale <= 1.0) return; // No need to zoom if data fits.

      // Translate to start at the day boundary (6h into the data).
      // 6h out of 36h total = 6/36 = 1/6 of the way through.
      // In pixels: (6 / 36) * chartInnerWidth * scale.
      final offsetFraction = 6.0 / totalHours;
      final tx = -(offsetFraction * chartInnerWidth * scale);

      _chartController.value = Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(0, 3, tx);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardDataAsync =
        ref.watch(trackableCardDataProvider(widget.trackableId));

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
            // --- Compact title row: name + stats + mode toggle + overflow menu ---
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
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _buildStatsText(data, mode),
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
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

            // --- Chart area ---
            if (hasDecay && data.curvePoints.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                key: _chartKey,
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

            // --- Toolbar row ---
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

  /// Mode toggle button: flips between decay and total focus.
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
        ref.read(databaseProvider).updateDashboardWidgetConfig(
          widget.widgetId!,
          jsonEncode(configMap),
        );
      },
    );
  }

  /// Builds the dual-mode chart with extended multi-day data.
  ///
  /// The data spans ~36h: 6h before day boundary → 6h after next boundary.
  /// Default viewport shows today's 24h period; user can pan to see carry-over.
  /// Faint vertical dashed lines mark the day boundaries (5 AM today, 5 AM tomorrow).
  Widget _buildDualModeChart(
    BuildContext context, {
    required TrackableCardData data,
    required Color trackableColor,
    required ChartMode mode,
  }) {
    final axisColor = Theme.of(context).colorScheme.onSurfaceVariant;
    // Use the day boundary as the X-axis zero reference.
    // Points before the boundary have negative X values (yesterday's carry-over).
    final chartStartTime = data.dayBoundaryTime;

    // Convert curve points to FlSpot(hours from day boundary, amount).
    final decaySpots = data.curvePoints.map((p) {
      final hoursFromStart =
          p.time.difference(chartStartTime).inMinutes / 60.0;
      return FlSpot(hoursFromStart, p.amount);
    }).toList();

    final cumulativeSpots = data.cumulativePoints.map((p) {
      final hoursFromStart =
          p.time.difference(chartStartTime).inMinutes / 60.0;
      return FlSpot(hoursFromStart, p.amount);
    }).toList();

    // Calculate max Y.
    double maxY;
    if (mode == ChartMode.total && cumulativeSpots.isNotEmpty) {
      maxY = cumulativeSpots.fold<double>(
          0, (max, s) => s.y > max ? s.y : max);
      for (final s in decaySpots) {
        if (s.y > maxY) maxY = s.y;
      }
    } else {
      maxY = decaySpots.fold<double>(0, (max, s) => s.y > max ? s.y : max);
      for (final s in cumulativeSpots) {
        if (s.y > maxY) maxY = s.y;
      }
    }

    // Filter thresholds by chart mode.
    final relevantComparisonType =
        mode == ChartMode.decay ? 'active_amount' : 'daily_total';
    final visibleThresholds = data.thresholds
        .where((t) => t.comparisonType == relevantComparisonType)
        .toList();

    for (final t in visibleThresholds) {
      if (t.amount > maxY) maxY = t.amount;
    }
    if (data.taperTarget != null && data.taperTarget! > maxY) {
      maxY = data.taperTarget!;
    }
    final adjustedMaxY = maxY > 0 ? maxY * 1.1 : 1.0;

    // X range: first and last data points (typically -6h to +30h from boundary).
    final minX = decaySpots.first.x;
    final maxX = decaySpots.last.x;
    final totalHours = maxX - minX;

    // "Now" indicator position.
    final isLive = ref.watch(selectedDateProvider) == null;
    final double? clampedNowHours;
    if (isLive) {
      final now = DateTime.now();
      final nowHours = now.difference(chartStartTime).inMinutes / 60.0;
      clampedNowHours = nowHours.clamp(minX, maxX);
    } else {
      clampedNowHours = null;
    }

    // Day boundary markers: vertical lines at X=0 (today's start) and
    // X=hours-to-next-boundary (tomorrow's start).
    final nextBoundaryHours =
        data.nextDayBoundaryTime.difference(chartStartTime).inMinutes / 60.0;

    // Apply initial zoom to focus on today's 24h period.
    _applyInitialZoom(totalHours);

    // Build line bars based on mode.
    final lineBars = <LineChartBarData>[];
    if (mode == ChartMode.decay) {
      lineBars.add(
          _buildPrimaryLine(decaySpots, trackableColor, isCurved: true));
      if (cumulativeSpots.isNotEmpty) {
        lineBars.add(_buildSecondaryLine(
            cumulativeSpots, trackableColor,
            isCurved: false));
      }
    } else {
      if (cumulativeSpots.isNotEmpty) {
        lineBars.add(_buildPrimaryLine(
            cumulativeSpots, trackableColor,
            isCurved: false));
      }
      lineBars.add(
          _buildSecondaryLine(decaySpots, trackableColor, isCurved: true));
    }

    return LineChart(
      transformationConfig: FlTransformationConfig(
        scaleAxis: FlScaleAxis.horizontal,
        minScale: 1.0,
        maxScale: 10.0,
        transformationController: _chartController,
      ),
      LineChartData(
        clipData: const FlClipData.all(),
        minX: minX,
        maxX: maxX,
        minY: 0,
        maxY: adjustedMaxY,

        lineBarsData: lineBars,

        extraLinesData: ExtraLinesData(
          verticalLines: [
            // Day boundary marker: start of today (X=0).
            VerticalLine(
              x: 0,
              color: axisColor.withAlpha(60),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
            // Day boundary marker: start of tomorrow.
            VerticalLine(
              x: nextBoundaryHours,
              color: axisColor.withAlpha(60),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
            // "Now" indicator — only in live mode.
            if (clampedNowHours != null)
              VerticalLine(
                x: clampedNowHours,
                color: axisColor.withAlpha(100),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
          ],
          horizontalLines: [
            for (final t in visibleThresholds)
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

        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          getTouchLineStart: (barData, spotIndex) => -double.infinity,
          getTouchLineEnd: (barData, spotIndex) => double.infinity,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                Theme.of(context).colorScheme.surfaceContainerHighest,
            getTooltipItems: (spots) {
              final hasTwo = spots.length == 2;
              final List<String?> labels;
              if (hasTwo) {
                labels = mode == ChartMode.decay
                    ? ['Active', 'Total']
                    : ['Total', 'Active'];
              } else {
                labels = [null];
              }
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

  /// Primary (focused) line: solid with gradient fill and shadow glow.
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
      shadow: Shadow(
        color: color.withAlpha(80),
        blurRadius: 4,
      ),
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withAlpha(50),
            color.withAlpha(0),
          ],
        ),
      ),
    );
  }

  /// Secondary (background) line: dashed, muted, no fill.
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

  /// Three-dot overflow menu mirroring the toolbar buttons.
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

  /// Stats text — changes based on chart mode.
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

  // --- Toolbar actions ---

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
