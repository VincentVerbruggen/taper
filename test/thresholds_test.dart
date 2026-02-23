import 'package:flutter_test/flutter_test.dart';

import 'package:taper/data/database.dart';

import 'helpers/test_database.dart';

/// Database-level tests for the Thresholds table with comparisonType column.
///
/// Verifies that:
/// - New thresholds default to 'daily_total' comparison type
/// - Insert accepts comparisonType parameter
/// - Update can change comparisonType
/// - Both types round-trip correctly
void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    try {
      await db.close();
    } catch (_) {}
  });

  test('inserted threshold defaults to daily_total comparisonType', () async {
    final id = await db.insertThreshold(1, 'Daily max', 400);

    final threshold = await (db.select(db.thresholds)
          ..where((t) => t.id.equals(id)))
        .getSingle();

    expect(threshold.name, 'Daily max');
    expect(threshold.amount, 400.0);
    // Default comparisonType should be 'daily_total'.
    expect(threshold.comparisonType, 'daily_total');
  });

  test('insert with active_amount comparisonType', () async {
    final id = await db.insertThreshold(
      1,
      'Safe level',
      200,
      comparisonType: 'active_amount',
    );

    final threshold = await (db.select(db.thresholds)
          ..where((t) => t.id.equals(id)))
        .getSingle();

    expect(threshold.comparisonType, 'active_amount');
  });

  test('updateThreshold changes comparisonType', () async {
    final id = await db.insertThreshold(1, 'Daily max', 400);

    // Update only comparisonType, leave name and amount unchanged.
    await db.updateThreshold(id, comparisonType: 'active_amount');

    final updated = await (db.select(db.thresholds)
          ..where((t) => t.id.equals(id)))
        .getSingle();

    expect(updated.name, 'Daily max');
    expect(updated.amount, 400.0);
    expect(updated.comparisonType, 'active_amount');
  });

  test('updateThreshold changes name without affecting comparisonType', () async {
    final id = await db.insertThreshold(
      1,
      'Safe level',
      200,
      comparisonType: 'active_amount',
    );

    await db.updateThreshold(id, name: 'Danger zone');

    final updated = await (db.select(db.thresholds)
          ..where((t) => t.id.equals(id)))
        .getSingle();

    expect(updated.name, 'Danger zone');
    expect(updated.comparisonType, 'active_amount');
  });

  test('watchThresholds returns thresholds with comparisonType', () async {
    await db.insertThreshold(1, 'Daily max', 400);
    await db.insertThreshold(
      1,
      'Active limit',
      200,
      comparisonType: 'active_amount',
    );

    final thresholds = await db.watchThresholds(1).first;

    expect(thresholds.length, 2);
    // Ordered by amount ascending: 200 first, then 400.
    expect(thresholds[0].name, 'Active limit');
    expect(thresholds[0].comparisonType, 'active_amount');
    expect(thresholds[1].name, 'Daily max');
    expect(thresholds[1].comparisonType, 'daily_total');
  });
}
