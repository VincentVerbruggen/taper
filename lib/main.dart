import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/screens/home_screen.dart';

/// App entry point.
///
/// ProviderScope = the DI container (like AppServiceProvider in Laravel).
/// It wraps the entire widget tree so every widget can access Riverpod
/// providers via ref.watch() / ref.read() — like app()->make() in Laravel.
void main() {
  runApp(
    const ProviderScope(child: TaperApp()),
  );
}

class TaperApp extends StatelessWidget {
  const TaperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taper',
      debugShowCheckedModeBanner: false,

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
