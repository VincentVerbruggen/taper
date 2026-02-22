import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/providers/backup_providers.dart';
import 'package:taper/screens/dashboard_screen.dart';
import 'package:taper/screens/log/log_dose_screen.dart';
import 'package:taper/screens/settings/settings_screen.dart';

/// HomeScreen = the app's main navigation shell.
///
/// Like layouts/app.blade.php in Laravel — provides the nav structure
/// and a content area that changes based on which tab is selected.
///
/// ConsumerStatefulWidget because:
///   1. The selected tab index is local UI state (needs setState).
///   2. We need ref.watch() to trigger the auto-backup on launch.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Trigger auto-backup on first build (runs once, result is cached).
    // FutureProvider returns AsyncValue — we just watch it for the side effect,
    // we don't need the result. Like a Laravel observer that fires on boot().
    ref.watch(autoBackupStartupProvider);

    return Scaffold(
      // IndexedStack keeps all tab screens alive (preserves scroll position,
      // form state, etc. when switching tabs). Like Vue's <keep-alive>.
      //
      // Without IndexedStack, switching tabs would destroy and rebuild the
      // screen each time — losing any open forms or scroll positions.
      // 3 tabs: Dashboard, Log, Settings (Trackables merged into Settings).
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          DashboardScreen(),
          LogDoseScreen(),
          SettingsScreen(),
        ],
      ),

      // NavigationBar = Material 3 bottom navigation.
      // Reduced from 4 to 3 tabs — Trackables moved into Settings.
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
