import 'package:flutter/material.dart';

import 'package:taper/screens/dashboard_screen.dart';
import 'package:taper/screens/log_screen.dart';
import 'package:taper/screens/substances/substances_screen.dart';

/// HomeScreen = the app's main navigation shell.
///
/// Like layouts/app.blade.php in Laravel — provides the nav structure
/// and a content area that changes based on which tab is selected.
///
/// StatefulWidget because the selected tab index is local UI state.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps all tab screens alive (preserves scroll position,
      // form state, etc. when switching tabs). Like Vue's <keep-alive>.
      //
      // Without IndexedStack, switching tabs would destroy and rebuild the
      // screen each time — losing any open forms or scroll positions.
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          DashboardScreen(),
          LogScreen(),
          SubstancesScreen(),
        ],
      ),

      // NavigationBar = Material 3 bottom navigation.
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
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science),
            label: 'Substances',
          ),
        ],
      ),
    );
  }
}
