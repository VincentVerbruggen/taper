import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taper/data/decay_model.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/utils/decay_calculator.dart';

/// Predictor widget showing when the active amount will drop below
/// the sleep threshold (e.g., "Ready for sleep in 3h 20m").
class SleepReadinessCard extends ConsumerWidget {
  final int trackableId;

  const SleepReadinessCard({super.key, required this.trackableId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardDataAsync = ref.watch(trackableCardDataProvider(trackableId));

    return cardDataAsync.when(
      loading: () => const SizedBox.shrink(),
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
    final threshold = trackable.sleepThreshold;

    // Only show if a sleep threshold is configured.
    if (threshold == null) {
      return const SizedBox.shrink();
    }

    final model = DecayModel.fromString(trackable.decayModel);
    // Only meaningful for trackables with a decay model.
    if (model == DecayModel.none) {
      return const SizedBox.shrink();
    }

    final activeAmount = data.activeAmount;
    final unit = trackable.unit;

    final double? hours;
    if (activeAmount <= threshold) {
      hours = 0;
    } else if (model == DecayModel.exponential) {
      hours = DecayCalculator.hoursToThreshold(
        currentActiveAmount: activeAmount,
        threshold: threshold,
        halfLifeHours: trackable.halfLifeHours!,
      );
    } else if (model == DecayModel.linear) {
      hours = DecayCalculator.hoursToThresholdLinear(
        currentActiveAmount: activeAmount,
        threshold: threshold,
        eliminationRate: trackable.eliminationRate!,
      );
    } else {
      hours = null;
    }

    final String message;
    final String timeStr;
    final bool isReady = activeAmount <= threshold;

    if (isReady) {
      message = 'Ready for sleep';
      timeStr = 'Now (below ${threshold.toStringAsFixed(0)} $unit)';
    } else if (hours == null) {
      message = 'Sleep readiness';
      timeStr = 'Unknown';
    } else {
      final duration = Duration(minutes: (hours * 60).round());
      final h = duration.inHours;
      final m = duration.inMinutes % 60;
      final now = DateTime.now();
      final readyAt = now.add(duration);
      final timeFormatter = TimeOfDay.fromDateTime(readyAt);

      message = 'Ready for sleep in';
      timeStr = '${h}h ${m}m (${timeFormatter.format(context)})';
    }

    final color = isReady
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bedtime_outlined,
                  size: 20,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  trackable.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              timeStr,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
