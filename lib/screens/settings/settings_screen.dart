import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/providers/settings_providers.dart';

/// Settings screen — the 4th tab in the bottom nav.
///
/// Currently just has one setting: the day boundary hour (when "today" starts).
/// Built as a simple ListView so more settings can be added later without
/// refactoring the layout.
///
/// Like a Laravel settings page (/settings/general) with form fields
/// that persist to the database (here: SharedPreferences).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boundaryHour = ref.watch(dayBoundaryHourProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),

            // --- Day boundary setting ---
            // ListTile with a dropdown on the trailing side.
            // The dropdown offers hours 0–12 (midnight to noon), formatted as "05:00".
            ListTile(
              title: const Text('Day starts at'),
              subtitle: const Text(
                'Doses logged before this time count as the previous day',
              ),
              trailing: DropdownButton<int>(
                value: boundaryHour,
                // Generate items for hours 0 through 12.
                // Formatted as "HH:00" — e.g., 5 → "05:00", 0 → "00:00".
                items: List.generate(13, (hour) {
                  final label = '${hour.toString().padLeft(2, '0')}:00';
                  return DropdownMenuItem<int>(
                    value: hour,
                    child: Text(label),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(dayBoundaryHourProvider.notifier).setHour(value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
