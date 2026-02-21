import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/home_screen.dart';
import 'package:taper/services/notification_service.dart';

/// Global navigator key — gives the notification service access to the
/// navigator for opening dialogs (like "Add Dose") from outside the widget tree.
/// Like Laravel's `app('router')` — a global handle to the navigation system.
final navigatorKey = GlobalKey<NavigatorState>();

/// App entry point.
///
/// ProviderScope = the DI container (like AppServiceProvider in Laravel).
/// It wraps the entire widget tree so every widget can access Riverpod
/// providers via ref.watch() / ref.read() — like app()->make() in Laravel.
void main() async {
  // ensureInitialized() must be called before any async work pre-runApp().
  // Flutter needs the binding set up before plugins (like notifications) can init.
  // Like calling `app()->boot()` before the service providers run.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the notification plugin (channels, action handler).
  // This just sets up the plumbing — no notification is shown yet.
  // Like registering a service provider in boot().
  // Initialize the notification plugin (channels, action handler).
  // This just sets up the plumbing — no notification is shown yet.
  // Like registering a service provider in boot().
  await NotificationService.instance.init();

  // Give the notification service the navigator key so it can open dialogs
  // (e.g., "Add Dose" quick-add dialog) from notification action callbacks.
  NotificationService.instance.navigatorKey = navigatorKey;

  // Load SharedPreferences before runApp so it's available synchronously
  // in all providers. Like loading config before booting the app container.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        // Inject the pre-loaded SharedPreferences instance so providers can
        // read settings synchronously (no FutureProvider needed).
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const TaperApp(),
    ),
  );
}

class TaperApp extends StatelessWidget {
  const TaperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taper',
      debugShowCheckedModeBanner: false,

      // navigatorKey connects MaterialApp's navigator to the notification service,
      // so notification actions can push routes/dialogs onto the navigation stack.
      // Like binding a global router instance in a SPA framework.
      navigatorKey: navigatorKey,

      // ColorScheme.fromSeed() generates a full color palette from one seed color —
      // like a CSS framework's theme generator. Pick one color, it derives all
      // surface, primary, secondary, error colors automatically.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),

      // ThemeMode.system follows the device setting.
      // Like CSS @media (prefers-color-scheme: dark).
      themeMode: ThemeMode.system,

      home: const HomeScreen(),
    );
  }
}
