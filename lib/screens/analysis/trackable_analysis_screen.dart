import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/analysis_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/utils/significant_digits_formatter.dart';

/// The quick-switch time windows offered on the detail screen.
///
/// `custom` falls back to the native date-range picker so any arbitrary span
/// is still reachable. Like preset filter buttons on an analytics dashboard
/// (Last 7 days / Last 30 days) plus a "custom range" escape hatch.
enum _Period { last7, last30, custom }

/// Single-trackable deep-dive: pick a period, see the daily consumption trend,
/// and compare it against the immediately-preceding equal-length period.
///
/// This is the drill-down you reach by tapping a card on the Analysis tab.
/// It's a ConsumerStatefulWidget because the selected period is local UI state
/// (like a `useState` in React), while the actual numbers come from a provider.
class TrackableAnalysisScreen extends ConsumerStatefulWidget {
  final Trackable trackable;

  const TrackableAnalysisScreen({super.key, required this.trackable});

  @override
  ConsumerState<TrackableAnalysisScreen> createState() =>
      _TrackableAnalysisScreenState();
}

class _TrackableAnalysisScreenState
    extends ConsumerState<TrackableAnalysisScreen> {
  _Period _period = _Period.last7;

  /// Only used when [_period] is [_Period.custom]. Null until the user picks.
  DateTimeRange? _customRange;

  /// Resolve the selected period into concrete date-only start/end values.
  ///
  /// We read "now" from nowProvider (an injectable clock) so widget tests can
  /// freeze time and keep the rolling windows deterministic.
  ({DateTime start, DateTime end}) _resolveRange() {
    final now = ref.read(nowProvider)();
    final today = DateTime(now.year, now.month, now.day);

    switch (_period) {
      case _Period.last7:
        // Rolling 7-day window: today plus the 6 days before it.
        return (start: _daysBefore(today, 6), end: today);
      case _Period.last30:
        return (start: _daysBefore(today, 29), end: today);
      case _Period.custom:
        final range = _customRange;
        if (range == null) {
          // Shouldn't happen (we only switch to custom after a pick), but stay
          // safe and fall back to the 7-day window.
          return (start: _daysBefore(today, 6), end: today);
        }
        return (
          start: DateTime(range.start.year, range.start.month, range.start.day),
          end: DateTime(range.end.year, range.end.month, range.end.day),
        );
    }
  }

  /// Subtract [days] using calendar arithmetic (DateTime handles rollover),
  /// which is DST-safe unlike subtracting a raw Duration of hours.
  DateTime _daysBefore(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day - days);

  Future<void> _pickCustomRange() async {
    final now = ref.read(nowProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final initial =
        _customRange ??
        DateTimeRange(start: _daysBefore(today, 6), end: today);

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: today,
      helpText: 'Select custom range',
      saveText: 'Apply',
    );

    if (picked == null) return; // user cancelled — keep current selection
    setState(() {
      _customRange = picked;
      _period = _Period.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final range = _resolveRange();
    final trackableColor = Color(widget.trackable.color);

    // Family provider keyed by (trackableId, start, end) — switching periods
    // just changes the key, so Riverpod fetches/caches each window separately.
    final dataAsync = ref.watch(
      trackableAnalysisProvider((
        trackableId: widget.trackable.id,
        start: range.start,
        end: range.end,
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: trackableColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.trackable.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildPeriodSelector(context),
            const SizedBox(height: 16),
            dataAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: $error'),
                ),
              ),
              data: (data) => Column(
                children: [
                  _ComparisonCard(
                    data: data,
                    unit: widget.trackable.unit,
                    accent: trackableColor,
                  ),
                  const SizedBox(height: 12),
                  _TrendChartCard(
                    data: data,
                    unit: widget.trackable.unit,
                    accent: trackableColor,
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(data: data, unit: widget.trackable.unit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Segmented preset switcher. Selecting "Custom" opens the date picker; the
  /// custom segment's label reflects the picked span once chosen.
  Widget _buildPeriodSelector(BuildContext context) {
    return SegmentedButton<_Period>(
      segments: [
        const ButtonSegment(value: _Period.last7, label: Text('7 days')),
        const ButtonSegment(value: _Period.last30, label: Text('30 days')),
        ButtonSegment(
          value: _Period.custom,
          label: Text(
            _period == _Period.custom && _customRange != null
                ? _formatCustomLabel(_customRange!)
                : 'Custom',
          ),
          icon: const Icon(Icons.date_range, size: 18),
        ),
      ],
      selected: {_period},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        final next = selection.first;
        if (next == _Period.custom) {
          // Always (re)open the picker when tapping custom so the user can
          // adjust an existing custom range too.
          _pickCustomRange();
        } else {
          setState(() => _period = next);
        }
      },
    );
  }

  String _formatCustomLabel(DateTimeRange range) {
    final days = range.end.difference(range.start).inDays + 1;
    return '${_formatShortDate(range.start)}–${_formatShortDate(range.end)} ($days d)';
  }

  String _formatShortDate(DateTime date) => '${date.month}/${date.day}';
}

/// "This period vs previous period" comparison, with a directional % badge.
///
/// Down = green (taper working), up = orange. When there's no prior data we
/// can't compute a ratio, so we say so instead of showing a fake 0%.
class _ComparisonCard extends StatelessWidget {
  final TrackableAnalysisData data;
  final String unit;
  final Color accent;

  const _ComparisonCard({
    required this.data,
    required this.unit,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = data.averageChangePercent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Compared to previous ${data.periodDays} days',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            _comparisonRow(
              context,
              label: 'This period',
              value: '${_fmt(data.averagePerDay)} $unit/day',
              emphasize: true,
            ),
            const SizedBox(height: 6),
            _comparisonRow(
              context,
              label: 'Previous ${data.periodDays} days',
              value: data.hasPreviousData
                  ? '${_fmt(data.previousAveragePerDay)} $unit/day'
                  : 'No data',
            ),
            const SizedBox(height: 12),
            if (change == null)
              Text(
                data.hasPreviousData
                    ? 'No prior consumption to compare against.'
                    : 'No data for the previous period to compare.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              _changeBadge(context, change),
          ],
        ),
      ),
    );
  }

  Widget _comparisonRow(
    BuildContext context, {
    required String label,
    required String value,
    bool emphasize = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: (emphasize
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyLarge)
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  /// The directional badge, e.g. "↓ 18% vs previous". Down is good for a taper.
  Widget _changeBadge(BuildContext context, double change) {
    // A tiny epsilon so a ~0% change reads as "no change" rather than a
    // misleading up/down arrow from floating-point noise.
    final isFlat = change.abs() < 0.05;
    final isDown = change < 0;

    final color = isFlat
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : (isDown ? Colors.green.shade600 : Colors.orange.shade700);
    final icon = isFlat
        ? Icons.trending_flat
        : (isDown ? Icons.south_east : Icons.north_east);
    final text = isFlat
        ? 'No change vs previous'
        : '${change.abs().toStringAsFixed(0)}% ${isDown ? 'lower' : 'higher'} vs previous';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.05) return rounded.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}

/// Daily-consumption bar chart. A downward slope over the period is exactly
/// what a successful taper looks like.
class _TrendChartCard extends StatelessWidget {
  final TrackableAnalysisData data;
  final String unit;
  final Color accent;

  const _TrendChartCard({
    required this.data,
    required this.unit,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final axisColor = theme.colorScheme.onSurfaceVariant;
    final points = data.dailyTotals;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily consumption', style: theme.textTheme.titleSmall),
            const SizedBox(height: 16),
            if (!data.hasDoses)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No doses logged in this period.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: axisColor,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 220,
                child: _buildChart(context, points, axisColor),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(
    BuildContext context,
    List<DailyTotalPoint> points,
    Color axisColor,
  ) {
    // Scale the Y axis with 10% headroom so the tallest bar doesn't touch the
    // top edge. Guard against an all-zero period (maxY must be > 0).
    final maxTotal = points.fold<double>(
      0,
      (maxValue, p) => p.total > maxValue ? p.total : maxValue,
    );
    final maxY = maxTotal > 0 ? maxTotal * 1.1 : 1.0;

    // With many days, thin the bars and the x-axis labels so nothing overlaps.
    final count = points.length;
    final barWidth = count > 20 ? 4.0 : (count > 10 ? 8.0 : 14.0);
    // Aim for ~6 date labels across the axis regardless of period length.
    final labelInterval = (count / 6).ceil().clamp(1, count);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        minY: 0,
        maxY: maxY,
        barGroups: [
          for (var i = 0; i < count; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].total,
                  color: accent,
                  width: barWidth,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                ),
              ],
            ),
        ],
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
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
                  formatWithSignificantDigits(value),
                  style: TextStyle(color: axisColor.withAlpha(150), fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= count) {
                  return const SizedBox.shrink();
                }
                // Label the first day, then every Nth, so the axis stays sparse.
                if (index != 0 && index % labelInterval != 0) {
                  return const SizedBox.shrink();
                }
                final day = points[index].day;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${day.month}/${day.day}',
                    style: TextStyle(
                      color: axisColor.withAlpha(150),
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = points[group.x].day;
              return BarTooltipItem(
                '${day.month}/${day.day}\n${_fmt(rod.toY)} $unit',
                TextStyle(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _fmt(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.05) return rounded.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}

/// Plain summary metrics for the current period.
class _SummaryCard extends StatelessWidget {
  final TrackableAnalysisData data;
  final String unit;

  const _SummaryCard({required this.data, required this.unit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This period', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            _row(context, 'Total', '${_fmt(data.total)} $unit'),
            _row(
              context,
              'Daily average',
              '${_fmt(data.averagePerDay)} $unit',
            ),
            _row(context, 'Daily high', '${_fmt(data.highestDayTotal)} $unit'),
            _row(context, 'Daily low', '${_fmt(data.lowestDayTotal)} $unit'),
            _row(context, 'Doses logged', '${data.doseCount}'),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.05) return rounded.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}
