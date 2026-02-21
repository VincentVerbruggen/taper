import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/settings/settings_screen.dart';

void main() {
  setUp(() async {
    // Initialize SharedPreferences with empty values for testing.
    // Like setting up a test .env file in Laravel.
    SharedPreferences.setMockInitialValues({});
  });

  // Helper to build with a pre-loaded SharedPreferences instance.
  Future<Widget> buildTestWidgetAsync({
    Map<String, Object>? initialPrefs,
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs ?? {});
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(
        home: SettingsScreen(),
      ),
    );
  }

  testWidgets('shows Settings header', (tester) async {
    final widget = await buildTestWidgetAsync();
    await tester.pumpWidget(widget);
    await tester.pump();

    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('shows day boundary dropdown with default 05:00', (tester) async {
    final widget = await buildTestWidgetAsync();
    await tester.pumpWidget(widget);
    await tester.pump();

    // The "Day starts at" setting should be visible.
    expect(find.text('Day starts at'), findsOneWidget);
    // Default value is 5 → "05:00" shown in the dropdown.
    expect(find.text('05:00'), findsOneWidget);
  });

  testWidgets('changing dropdown persists new value', (tester) async {
    final widget = await buildTestWidgetAsync();
    await tester.pumpWidget(widget);
    await tester.pump();

    // Open the dropdown by tapping the current value.
    await tester.tap(find.text('05:00'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Select "03:00" from the dropdown menu.
    // The dropdown overlay shows all 13 items (0-12). Find "03:00" in the
    // overlay and tap it. There may be two "05:00" widgets (selected + list).
    await tester.tap(find.text('03:00').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The dropdown should now show "03:00" as selected.
    // After selection, the dropdown may still have an overlay item animating out,
    // so we check for at least one widget showing the new value.
    expect(find.text('03:00'), findsWidgets);

    // Verify the value was persisted to SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('dayBoundaryHour'), 3);
  });

  testWidgets('loads previously saved value', (tester) async {
    // Pre-set the boundary to 8 AM.
    final widget = await buildTestWidgetAsync(
      initialPrefs: {'dayBoundaryHour': 8},
    );
    await tester.pumpWidget(widget);
    await tester.pump();

    // The dropdown should show "08:00" (not the default "05:00").
    expect(find.text('08:00'), findsOneWidget);
  });
}
