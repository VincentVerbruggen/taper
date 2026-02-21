import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/dashboard/widgets/substance_card.dart';

/// Dashboard tab — shows a card for each visible substance with decay stats.
///
/// Each card loads independently via substanceCardDataProvider.family, so
/// they appear as their data becomes ready (staggered loading).
///
/// Like a Laravel dashboard with multiple Livewire components:
///   `@foreach($substances as $substance)`
///       `<livewire:substance-card :id="$substance->id" />`
///   `@endforeach`
///
/// ConsumerWidget because we watch the visible substances provider.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final substancesAsync = ref.watch(visibleSubstancesProvider);

    return substancesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (substances) {
        // Empty state: no visible substances configured.
        if (substances.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'No visible substances.\nGo to the Substances tab to add or unhide one.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // SafeArea(bottom: false) pushes content below the status bar
        // without adding padding at the bottom (the tab bar handles that).
        // Like adding `padding-top: env(safe-area-inset-top)` in CSS.
        return SafeArea(
          bottom: false,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            // +1 for the header row at index 0.
            itemCount: substances.length + 1,
            itemBuilder: (context, index) {
              // First item = "Dashboard" heading, matching other screens' style.
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Dashboard',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                );
              }

              // Subtract 1 to get the real substance index (header took slot 0).
              final substance = substances[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SubstanceCard(substanceId: substance.id),
              );
            },
          ),
        );
      },
    );
  }
}
