import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/trackables/add_taper_plan_screen.dart';

/// Dedicated screen for managing taper plans for a trackable.
///
/// Shows plan history with status labels (Active/Completed/Superseded),
/// retry button (copies params to a new plan), and delete.
///
/// Like an order history section in a customer portal:
///   Route::resource('trackables/{trackable}/taper-plans', TaperPlanController::class)
class TaperPlansScreen extends ConsumerWidget {
  /// The trackable whose taper plans we're managing.
  final Trackable trackable;

  const TaperPlansScreen({super.key, required this.trackable});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch taper plans reactively — list updates on add/delete.
    final plansAsync = ref.watch(taperPlansProvider(trackable.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taper Plans'),
      ),
      // FAB to create a new taper plan — navigates to the full creation form.
      floatingActionButton: FloatingActionButton(
        heroTag: 'taperPlansFab',
        onPressed: () => _addTaperPlan(context),
        child: const Icon(Icons.add),
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error loading taper plans: $e')),
        data: (plansList) {
          if (plansList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No taper plans yet.\nTap + to create one.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plansList.length,
            itemBuilder: (context, index) {
              final plan = plansList[index];
              final status = _taperPlanStatus(plan);
              final shape = RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Card(
                  shape: shape,
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    // "400 → 100 mg" — start and target amounts.
                    title: Text(
                      '${plan.startAmount.toStringAsFixed(0)} → ${plan.targetAmount.toStringAsFixed(0)} ${trackable.unit}',
                    ),
                    // Date range + status chip. Format: "Feb 1 – Mar 15 · Active"
                    subtitle: Text(
                      '${_formatDate(plan.startDate)} – ${_formatDate(plan.endDate)} · $status',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Retry: copies this plan's params into a new plan form.
                        // Like duplicating an order with updated dates.
                        IconButton(
                          icon: const Icon(Icons.replay, size: 20),
                          tooltip: 'Retry with same settings',
                          onPressed: () => _retryTaperPlan(context, plan),
                        ),
                        // Delete: removes the plan.
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          tooltip: 'Delete plan',
                          onPressed: () {
                            ref.read(databaseProvider).deleteTaperPlan(plan.id);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Determines the status label for a taper plan.
  ///
  /// - Active: isActive == true (could be before start, in progress, or maintenance)
  /// - Completed: isActive == false AND endDate is in the past
  /// - Superseded: isActive == false AND endDate is NOT in the past
  ///   (replaced by a newer plan before it finished)
  String _taperPlanStatus(TaperPlan plan) {
    if (plan.isActive) return 'Active';
    // If inactive, check if the plan ran to completion or was superseded early.
    if (plan.endDate.isBefore(DateTime.now())) return 'Completed';
    return 'Superseded';
  }

  /// Format a date as "Feb 1" or "Mar 15" for compact display in plan cards.
  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  /// Navigate to AddTaperPlanScreen pre-filled with an old plan's amounts (Retry flow).
  /// Like duplicating a record in a CRUD list.
  void _retryTaperPlan(BuildContext context, TaperPlan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaperPlanScreen(
          trackable: trackable,
          initialStartAmount: plan.startAmount,
          initialTargetAmount: plan.targetAmount,
        ),
      ),
    );
  }

  /// Navigate to AddTaperPlanScreen with empty defaults.
  void _addTaperPlan(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaperPlanScreen(trackable: trackable),
      ),
    );
  }
}
