import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/trackables/add_target_screen.dart';

import 'helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late Trackable caffeine;

  setUp(() async {
    db = createTestDatabase();
    final trackables = await db.select(db.trackables).get();
    caffeine = trackables.firstWhere((t) => t.name == 'Caffeine');
  });

  tearDown(() async {
    try {
      await db.close();
    } catch (_) {}
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: AddTargetScreen(trackable: caffeine)),
    );
  }

  testWidgets('shows inline error when amount is not numeric', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Bedtime');
    await tester.enterText(find.byType(TextFormField).last, 'abc');

    // Submit to trigger Form validators. This mirrors the app pattern where
    // validation feedback appears at submit time, not while the user is typing.
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid number'), findsOneWidget);
  });
}
