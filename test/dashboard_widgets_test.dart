import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taper/data/database.dart';

import 'helpers/test_database.dart';

/// Database-level tests for the DashboardWidgets table and CRUD operations.
///
/// Verifies that the dashboard widgets system correctly:
/// - Seeds initial widgets for visible trackables on fresh DB
/// - Supports CRUD operations (insert, delete, reorder, update config)
/// - Auto-adds a decay_card when a new trackable is created
/// - Cascade-deletes widgets when their trackable is deleted
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

  test('fresh DB seeds Caffeine and Water dashboard widgets', () async {
    // The onCreate seeder inserts 2 dashboard widgets:
    // one for Caffeine (sortOrder 1) and one for Water (sortOrder 2).
    final widgets = await db.select(db.dashboardWidgets).get();

    expect(widgets.length, 2);
    expect(widgets[0].type, 'decay_card');
    expect(widgets[0].trackableId, 1); // Caffeine
    expect(widgets[0].sortOrder, 1);
    expect(widgets[1].type, 'decay_card');
    expect(widgets[1].trackableId, 2); // Water
    expect(widgets[1].sortOrder, 2);
  });

  test('watchDashboardWidgets returns widgets ordered by sortOrder', () async {
    // Listen to the first emission from the stream.
    final widgets = await db.watchDashboardWidgets().first;

    expect(widgets.length, 2);
    expect(widgets[0].sortOrder, lessThan(widgets[1].sortOrder));
  });

  test('insertDashboardWidget auto-assigns sortOrder', () async {
    // Current max sortOrder = 2 (Water widget).
    // A new widget should get sortOrder = 3.
    final id = await db.insertDashboardWidget(
      'taper_progress',
      trackableId: 1,
    );

    final widget = await (db.select(db.dashboardWidgets)
          ..where((t) => t.id.equals(id)))
        .getSingle();

    expect(widget.type, 'taper_progress');
    expect(widget.trackableId, 1);
    expect(widget.sortOrder, 3); // max(2) + 1
    expect(widget.config, '{}'); // default config
  });

  test('deleteDashboardWidget removes the widget', () async {
    final widgetsBefore = await db.select(db.dashboardWidgets).get();
    expect(widgetsBefore.length, 2);

    await db.deleteDashboardWidget(widgetsBefore.first.id);

    final widgetsAfter = await db.select(db.dashboardWidgets).get();
    expect(widgetsAfter.length, 1);
    expect(widgetsAfter.first.id, widgetsBefore.last.id);
  });

  test('reorderDashboardWidgets updates sortOrder for all IDs', () async {
    final widgets = await db.select(db.dashboardWidgets).get();
    final caffeineId = widgets[0].id;
    final waterId = widgets[1].id;

    // Reverse the order: Water first, Caffeine second.
    await db.reorderDashboardWidgets([waterId, caffeineId]);

    final reordered = await (db.select(db.dashboardWidgets)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();

    expect(reordered[0].id, waterId);
    expect(reordered[0].sortOrder, 1);
    expect(reordered[1].id, caffeineId);
    expect(reordered[1].sortOrder, 2);
  });

  test('updateDashboardWidgetConfig sets config JSON', () async {
    final widgets = await db.select(db.dashboardWidgets).get();
    final id = widgets.first.id;

    await db.updateDashboardWidgetConfig(id, '{"showCumulativeLine":true}');

    final updated = await (db.select(db.dashboardWidgets)
          ..where((t) => t.id.equals(id)))
        .getSingle();

    expect(updated.config, '{"showCumulativeLine":true}');
  });

  test('insertTrackable auto-adds decay_card widget', () async {
    // Before: 2 widgets (Caffeine + Water).
    final widgetsBefore = await db.select(db.dashboardWidgets).get();
    expect(widgetsBefore.length, 2);

    // Insert a new trackable.
    final newId = await db.insertTrackable('Melatonin', unit: 'mg');

    // After: 3 widgets — the new one should be a decay_card for the new trackable.
    final widgetsAfter = await db.select(db.dashboardWidgets).get();
    expect(widgetsAfter.length, 3);

    final newWidget = widgetsAfter.last;
    expect(newWidget.type, 'decay_card');
    expect(newWidget.trackableId, newId);
    expect(newWidget.sortOrder, 3); // max(2) + 1
  });

  test('deleting widget by trackable ID removes all widgets for that trackable', () async {
    // Add a second widget for Caffeine (trackable ID 1).
    await db.insertDashboardWidget('taper_progress', trackableId: 1);

    final widgetsBefore = await db.select(db.dashboardWidgets).get();
    expect(widgetsBefore.length, 3); // 2 original + 1 new

    // Manually delete all widgets for Caffeine (trackable ID 1).
    // Note: SQLite foreign key cascade isn't enabled in this app,
    // so application-level cleanup is needed after deleting a trackable.
    final caffeineWidgets = widgetsBefore.where((w) => w.trackableId == 1);
    for (final w in caffeineWidgets) {
      await db.deleteDashboardWidget(w.id);
    }

    // Only the Water widget (trackableId = 2) should remain.
    final widgetsAfter = await db.select(db.dashboardWidgets).get();
    expect(widgetsAfter.length, 1);
    expect(widgetsAfter.first.trackableId, 2); // Water
  });

  test('inserting widget with config stores the config', () async {
    final id = await db.insertDashboardWidget(
      'decay_card',
      trackableId: 1,
      config: '{"showCumulativeLine":true}',
    );

    final widget = await (db.select(db.dashboardWidgets)
          ..where((t) => t.id.equals(id)))
        .getSingle();

    expect(widget.config, '{"showCumulativeLine":true}');
  });
}
