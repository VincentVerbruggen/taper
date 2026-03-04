import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/providers/analysis_providers.dart';
import 'package:taper/providers/settings_providers.dart';

/// Analysis tab — range-based summary metrics across trackables.
///
/// This gives a "report view" for a selected date range: high/low/average
/// day totals, plus dose-level averages. Think of it like an analytics page
/// in a web admin panel where filters drive aggregate cards.
class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRange = ref.watch(analysisDateRangeProvider);
    final statsAsync = ref.watch(analysisStatsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: statsAsync.when(
          loading: () => _buildStateScaffold(
            context,
            headerRange: selectedRange,
            content: const Center(child: CircularProgressIndicator()),
            onPickRange: () => _pickDateRange(context, ref, selectedRange),
          ),
          error: (error, stack) => _buildStateScaffold(
            context,
            headerRange: selectedRange,
            content: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: $error'),
            ),
            onPickRange: () => _pickDateRange(context, ref, selectedRange),
          ),
          data: (stats) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _buildHeader(
                context,
                selectedRange,
                onPickRange: () => _pickDateRange(context, ref, selectedRange),
              ),
              const SizedBox(height: 12),

              // Range-level summary is like a SQL GROUP BY "overall totals"
              // row: one quick glance before diving into per-trackable cards.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${stats.totalDays} day range',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${stats.overallDoseCount} doses logged',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total across trackables: ${_formatAmount(stats.overallTotalAmount)} units',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Day starts at ${_formatHour(stats.boundaryHour)} (from Settings)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              if (stats.trackableStats.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No trackables available for analysis.'),
                  ),
                )
              else
                ...stats.trackableStats.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TrackableStatsCard(stats: row),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shared scaffold for loading/error states so the header remains visible.
  Widget _buildStateScaffold(
    BuildContext context, {
    required DateTimeRange headerRange,
    required Widget content,
    required VoidCallback onPickRange,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildHeader(context, headerRange, onPickRange: onPickRange),
        const SizedBox(height: 20),
        content,
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    DateTimeRange range, {
    required VoidCallback onPickRange,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            'Analysis',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onPickRange,
          icon: const Icon(Icons.date_range),
          label: Text(_formatDateRange(range)),
        ),
      ],
    );
  }

  /// Opens the native date-range picker and stores the chosen range.
  Future<void> _pickDateRange(
    BuildContext context,
    WidgetRef ref,
    DateTimeRange currentRange,
  ) async {
    // Read "now" from provider so tests can freeze time and keep picker limits
    // deterministic. This avoids flaky tests around midnight.
    final now = ref.read(nowProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: currentRange,
      firstDate: DateTime(2020, 1, 1),
      lastDate: today,
      helpText: 'Select analysis range',
      saveText: 'Apply',
    );

    if (picked == null) return;
    ref.read(analysisDateRangeProvider.notifier).setRange(picked);
  }

  String _formatDateRange(DateTimeRange range) {
    final start = _formatDate(range.start);
    final end = _formatDate(range.end);
    return '$start - $end';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _formatHour(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  /// Format doubles for compact metric display:
  /// - integers => no decimal ("120")
  /// - fractions => one decimal ("120.5")
  String _formatAmount(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.05) {
      return rounded.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

/// One per-trackable analysis card with daily and dose-level metrics.
class _TrackableStatsCard extends StatelessWidget {
  final TrackableRangeStats stats;

  const _TrackableStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Color(stats.trackable.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stats.trackable.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${stats.doseCount} doses',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (!stats.hasDoses)
              Text(
                'No doses logged in this range.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              _MetricRow(
                left: _MetricValue(
                  label: 'Total',
                  value:
                      '${_formatAmount(stats.totalAmount)} ${stats.trackable.unit}',
                ),
                right: _MetricValue(
                  label: 'Daily average',
                  value:
                      '${_formatAmount(stats.averageDayTotal)} ${stats.trackable.unit}',
                ),
              ),
              const SizedBox(height: 10),
              _MetricRow(
                left: _MetricValue(
                  label: 'Daily high',
                  value:
                      '${_formatAmount(stats.highestDayTotal)} ${stats.trackable.unit}',
                ),
                right: _MetricValue(
                  label: 'Daily low',
                  value:
                      '${_formatAmount(stats.lowestDayTotal)} ${stats.trackable.unit}',
                ),
              ),
              const SizedBox(height: 10),
              _MetricRow(
                left: _MetricValue(
                  label: 'Dose average',
                  value:
                      '${_formatAmount(stats.averageDoseAmount)} ${stats.trackable.unit}',
                ),
                right: _MetricValue(
                  label: 'Dose range',
                  value:
                      '${_formatAmount(stats.lowestDoseAmount)} - ${_formatAmount(stats.highestDoseAmount)} ${stats.trackable.unit}',
                ),
              ),
              const SizedBox(height: 10),
              _MetricValue(
                label: 'Peak active concentration',
                value: _formatPeakActive(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatAmount(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.05) {
      return rounded.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  /// For decay-enabled trackables, show the peak active amount in the range.
  /// For non-decay trackables (decayModel = none), concentration is undefined.
  String _formatPeakActive() {
    if (stats.highestActiveAmount == null) {
      return 'N/A (no decay model)';
    }
    return '${_formatAmount(stats.highestActiveAmount!)} ${stats.trackable.unit}';
  }
}

/// Two-column metrics row used in each trackable card.
class _MetricRow extends StatelessWidget {
  final _MetricValue left;
  final _MetricValue right;

  const _MetricRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

/// Small label/value block for one metric.
class _MetricValue extends StatelessWidget {
  final String label;
  final String value;

  const _MetricValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
