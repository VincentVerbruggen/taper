import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// Code generator output — run: dart run build_runner build --delete-conflicting-outputs
part 'database.g.dart';

/// 10 distinct colors for auto-assigning to trackables, stored as ARGB ints.
/// These will be used for chart lines in the decay curve (Milestone 4).
/// Colors are spread across the hue wheel for maximum contrast.
/// Like a Tailwind color palette: ['red-500', 'blue-500', 'green-500', ...].
const trackableColorPalette = [
  0xFF4CAF50, // Green (Caffeine default)
  0xFF2196F3, // Blue
  0xFFF44336, // Red
  0xFFFF9800, // Orange
  0xFF9C27B0, // Purple
  0xFF00BCD4, // Cyan
  0xFFFFEB3B, // Yellow
  0xFFE91E63, // Pink
  0xFF795548, // Brown
  0xFF607D8B, // Blue Grey
];

/// Trackables table.
/// Laravel equivalent: Schema::create('trackables', ...) + Eloquent model.
class Trackables extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  // Whether this trackable is the "default" in the Log form dropdown.
  // Only one trackable can be main at a time — like a radio button.
  // withDefault(false) makes it optional in insert() calls, so existing
  // code that just passes a name keeps working.
  // Laravel equivalent: $table->boolean('is_main')->default(false)
  BoolColumn get isMain => boolean().withDefault(const Constant(false))();

  // Whether this trackable appears in the Log form dropdown.
  // Hidden trackables keep their dose history but don't clutter the UI.
  // Defaults to true so new trackables are visible immediately.
  // Laravel equivalent: $table->boolean('is_visible')->default(true)
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();

  // Biological half-life in hours (e.g., 5.0 for caffeine).
  // Nullable: null means no decay tracking (e.g., Water has no half-life).
  // Used by the decay curve chart to calculate how much is still active.
  // Laravel equivalent: $table->double('half_life_hours')->nullable()
  RealColumn get halfLifeHours => real().nullable()();

  // Unit of measurement for doses (e.g., "mg", "ml", "IU").
  // Free text, defaults to "mg". Displayed in the Log form suffix and
  // recent logs list. Stored on the trackable, not the dose log.
  // Laravel equivalent: $table->string('unit')->default('mg')
  TextColumn get unit => text().withDefault(const Constant('mg'))();

  // Auto-assigned color from trackableColorPalette (ARGB int).
  // Used for chart lines in the decay curve. No user-facing picker yet.
  // Non-nullable — always explicitly set during insert.
  // Laravel equivalent: $table->unsignedInteger('color')
  IntColumn get color => integer()();

  // User-controlled display order. Lower values appear first.
  // Default 0 so existing rows get a value; on insert we auto-assign max+1.
  // Used by the dashboard card list and the trackables management screen.
  // Laravel equivalent: $table->unsignedInteger('sort_order')->default(0)
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  // Decay model type: 'none', 'exponential', or 'linear'.
  // Determines which decay formula is used for the dashboard chart.
  // Default 'none' means no decay tracking (like Water).
  // Stored as text rather than int for readability in DB browsers.
  // Laravel equivalent: $table->string('decay_model')->default('none')
  TextColumn get decayModel => text().withDefault(const Constant('none'))();

  // Elimination rate in units-per-hour for linear decay model.
  // E.g., alcohol ≈ 9 ml/hour (one standard drink per hour).
  // Only used when decayModel = 'linear'; null for other models.
  // Laravel equivalent: $table->double('elimination_rate')->nullable()
  RealColumn get eliminationRate => real().nullable()();

  // Absorption time in minutes. When set, doses ramp up linearly
  // from 0 to full amount over this period before decay begins.
  // E.g., caffeine takes ~45 min to reach peak blood levels.
  // Nullable: null means instant absorption (existing default behavior).
  // Laravel equivalent: $table->double('absorption_minutes')->nullable()
  RealColumn get absorptionMinutes => real().nullable()();

  // Whether to overlay a cumulative intake staircase line on the decay chart.
  // When true, a second line shows total consumed throughout the day (goes up
  // with each dose, never comes down). Only meaningful when decay model != none.
  // Laravel equivalent: $table->boolean('show_cumulative_line')->default(false)
  BoolColumn get showCumulativeLine =>
      boolean().withDefault(const Constant(false))();
}

/// Presets table — named dose shortcuts per trackable.
///
/// E.g., "Espresso" = 90 mg, "Glass of wine" = 150 ml.
/// Users can tap a preset chip to fill the amount field instead of typing.
///
/// Laravel equivalent:
///   Schema::create('presets', function (Blueprint $table) {
///       $table->id();
///       $table->foreignId('trackable_id')->constrained()->cascadeOnDelete();
///       $table->string('name');
///       $table->double('amount');
///       $table->unsignedInteger('sort_order')->default(0);
///   });
class Presets extends Table {
  IntColumn get id => integer().autoIncrement()();

  // FK to trackables table. When a trackable is deleted, its presets go too.
  IntColumn get trackableId => integer().references(Trackables, #id)();

  // Human-readable label, e.g., "Espresso", "Double Shot".
  TextColumn get name => text()();

  // The dose amount this preset fills in, e.g., 90.0.
  RealColumn get amount => real()();

  // User-controlled display order within a trackable's presets.
  // Default 0 so existing rows get a value; on insert we auto-assign max+1.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Dose logs table — records each time a user takes a dose of a trackable.
///
/// Laravel equivalent:
///   Schema::create('dose_logs', function (Blueprint $table) {
///       $table->id();
///       $table->foreignId('trackable_id')->constrained()->cascadeOnDelete();
///       $table->double('amount_mg');
///       $table->dateTime('logged_at');
///   });
///
/// references() sets up a foreign key constraint — like $table->foreignId()->constrained().
/// When a trackable is deleted, all its dose logs are cascade-deleted too.
class DoseLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  // FK to trackables table. references() = $table->foreignId()->constrained().
  IntColumn get trackableId => integer().references(Trackables, #id)();

  // real() = REAL column in SQLite, stores doubles.
  // Renamed from amountMg — the unit now comes from the trackable table.
  // Like $table->double('amount').
  RealColumn get amount => real()();

  // dateTime() stores as integer (epoch seconds) in SQLite.
  // Like $table->dateTime('logged_at').
  DateTimeColumn get loggedAt => dateTime()();

  // Optional name from a preset (e.g., "Espresso", "Filter coffee").
  // Populated automatically when a dose is logged via a preset chip;
  // null for manually entered amounts. Users can't set this directly.
  // Laravel equivalent: $table->string('name')->nullable()
  TextColumn get name => text().nullable()();
}

/// Taper plans table — gradual reduction schedules per trackable.
///
/// Each plan defines a linear ramp from startAmount to targetAmount over a
/// date range. After endDate, the target stays flat at targetAmount
/// (maintenance mode) until superseded by a new plan.
///
/// Plans are immutable once created. To adjust, create a new plan which
/// atomically deactivates the old one (via a transaction in insertTaperPlan).
///
/// Only one plan per trackable can be active at a time (isActive = true).
///
/// Laravel equivalent:
///   Schema::create('taper_plans', function (Blueprint $table) {
///       $table->id();
///       $table->foreignId('trackable_id')->constrained()->cascadeOnDelete();
///       $table->double('start_amount');
///       $table->double('target_amount');
///       $table->dateTime('start_date');
///       $table->dateTime('end_date');
///       $table->boolean('is_active')->default(true);
///   });
class TaperPlans extends Table {
  IntColumn get id => integer().autoIncrement()();

  // FK to trackables table. When a trackable is deleted, its plans go too.
  IntColumn get trackableId => integer().references(Trackables, #id)();

  // Daily target on day 1 of the taper (e.g., 400 mg).
  RealColumn get startAmount => real()();

  // Daily target on the final day / maintenance (e.g., 100 mg).
  RealColumn get targetAmount => real()();

  // First day boundary of the taper schedule.
  // Stored as epoch seconds (SQLite integer) via Drift's dateTime().
  DateTimeColumn get startDate => dateTime()();

  // Last day boundary of the taper schedule.
  DateTimeColumn get endDate => dateTime()();

  // Only one active plan per trackable at a time.
  // When a new plan is created, the old one gets deactivated in a transaction.
  // Default true — new plans start active.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Thresholds table — named horizontal lines per trackable.
///
/// Each trackable can have multiple thresholds (e.g., "Daily max" = 400 mg,
/// "Bedtime cutoff" = 200 mg). These appear as dashed horizontal lines on
/// the decay curve chart and help users visualize safe/target levels.
///
/// Laravel equivalent:
///   Schema::create('thresholds', function (Blueprint $table) {
///       $table->id();
///       $table->foreignId('trackable_id')->constrained()->cascadeOnDelete();
///       $table->string('name');
///       $table->double('amount');
///   });
class Thresholds extends Table {
  IntColumn get id => integer().autoIncrement()();

  // FK to trackables table. When a trackable is deleted, its thresholds go too.
  IntColumn get trackableId => integer().references(Trackables, #id)();

  // Human-readable label, e.g., "Daily max", "Bedtime cutoff".
  TextColumn get name => text()();

  // The amount value where the horizontal line is drawn on the chart.
  RealColumn get amount => real()();
}

/// Dashboard widgets table — decouples "what's on the dashboard" from trackable visibility.
///
/// Each widget is a card on the dashboard that shows a view of a trackable's data.
/// Multiple widgets can reference the same trackable (e.g., decay card + taper progress).
/// Trackable visibility (isVisible) only controls the log form dropdown now.
///
/// Laravel equivalent:
///   Schema::create('dashboard_widgets', function (Blueprint $table) {
///       $table->id();
///       $table->string('type');  // 'decay_card' or 'taper_progress'
///       $table->foreignId('trackable_id')->nullable()->constrained()->cascadeOnDelete();
///       $table->unsignedInteger('sort_order')->default(0);
///       $table->text('config')->default('{}');
///   });
class DashboardWidgets extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Widget type: 'decay_card' or 'taper_progress'.
  // Determines which widget component to render on the dashboard.
  // Stored as text for readability and extensibility.
  TextColumn get type => text()();

  // FK to trackables table. Nullable so future widget types might not need a trackable.
  // Cascade delete: if the trackable is removed, its dashboard widgets go too.
  // Like $table->foreignId('trackable_id')->nullable()->constrained()->cascadeOnDelete()
  IntColumn get trackableId => integer().nullable().references(Trackables, #id)();

  // User-controlled display order. Lower values appear first on the dashboard.
  // Same pattern as Trackables.sortOrder — auto-assigned max+1 on insert.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  // JSON blob for per-widget settings (e.g., showCumulativeLine for decay cards).
  // Default '{}' = no custom config. Parsed by individual widget components.
  // Like a Laravel JSON column: $table->json('config')->default('{}')
  TextColumn get config => text().withDefault(const Constant('{}'))();
}

/// AppDatabase = the database singleton.
/// Like DatabaseServiceProvider + config/database.php in Laravel.
@DriftDatabase(tables: [Trackables, DoseLogs, Presets, Thresholds, TaperPlans, DashboardWidgets])
class AppDatabase extends _$AppDatabase {
  // Default constructor uses platform-specific SQLite via drift_flutter.
  AppDatabase() : super(driftDatabase(name: 'taper'));

  // Named constructor for tests — accepts any QueryExecutor (e.g., in-memory DB).
  // Like Laravel's DB_CONNECTION=sqlite :memory: in phpunit.xml.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // onCreate = fresh install. Creates all tables and seeds structural data.
    // Only seeds the 3 default trackables — demo data (presets, thresholds,
    // dose logs) is seeded separately by seedDemoData() on first app launch.
    // Like php artisan migrate — schema + minimal seeds only.
    onCreate: (Migrator m) async {
      await m.createAll();

      // Caffeine: visible, exponential decay with 5h half-life and 45min absorption.
      // halfLifeHours=5.0 = caffeine's biological half-life (used for decay curve).
      // absorptionMinutes=45 = time for caffeine to reach peak blood levels.
      await into(trackables).insert(
        TrackablesCompanion.insert(
          name: 'Caffeine',
          isMain: const Value(true),
          halfLifeHours: const Value(5.0),
          absorptionMinutes: const Value(45.0),
          unit: const Value('mg'),
          color: trackableColorPalette[0],
          sortOrder: const Value(1),
          decayModel: const Value('exponential'),
        ),
      );
      // Water: visible, no decay tracking (just counts totals).
      await into(trackables).insert(
        TrackablesCompanion.insert(
          name: 'Water',
          halfLifeHours: const Value(null),
          unit: const Value('ml'),
          color: trackableColorPalette[1],
          sortOrder: const Value(2),
          // decayModel defaults to 'none'
        ),
      );
      // Alcohol: hidden, linear decay at 9 ml/hour.
      // Alcohol follows zero-order kinetics: the liver processes a fixed
      // amount per hour regardless of BAC (≈1 standard drink/hr ≈ 9 ml pure alcohol).
      await into(trackables).insert(
        TrackablesCompanion.insert(
          name: 'Alcohol',
          isVisible: const Value(false),
          unit: const Value('ml'),
          color: trackableColorPalette[2],
          sortOrder: const Value(3),
          decayModel: const Value('linear'),
          eliminationRate: const Value(9.0),
        ),
      );

      // Seed dashboard widgets for the 2 visible trackables (Caffeine + Water).
      // Alcohol is hidden so no widget. IDs are 1 and 2 because autoIncrement
      // assigns them in insertion order on a fresh database.
      // Like: DashboardWidget::insert([['type' => 'decay_card', 'trackable_id' => 1, ...]])
      await into(dashboardWidgets).insert(
        DashboardWidgetsCompanion.insert(
          type: 'decay_card',
          trackableId: const Value(1),
          sortOrder: const Value(1),
        ),
      );
      await into(dashboardWidgets).insert(
        DashboardWidgetsCompanion.insert(
          type: 'decay_card',
          trackableId: const Value(2),
          sortOrder: const Value(2),
        ),
      );
    },

    // onUpgrade = existing install. Runs when schemaVersion increases.
    // Like Laravel's php artisan migrate — runs only the new migrations.
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // v1 → v2: add the dose_logs table.
        await m.createTable(doseLogs);
      }
      if (from < 3) {
        // v2 → v3: add isMain and isVisible columns to trackables.
        // m.addColumn() generates: ALTER TABLE trackables ADD COLUMN is_main INTEGER NOT NULL DEFAULT 0
        // Existing rows get the default value automatically — like Laravel's migration with ->default().
        await m.addColumn(trackables, trackables.isMain);
        await m.addColumn(trackables, trackables.isVisible);

        // Seed Water and Alcohol for existing installs too, so they have
        // something to see the visibility difference with.
        await into(trackables).insert(
          TrackablesCompanion.insert(name: 'Water', color: 0),
        );
        await into(trackables).insert(
          TrackablesCompanion.insert(
            name: 'Alcohol',
            isVisible: const Value(false),
            color: 0,
          ),
        );
      }
      if (from < 4) {
        // v3 → v4: Add halfLifeHours, unit, and color to trackables;
        // rename amount_mg → amount in dose_logs.

        // Nullable column — existing rows get NULL (no decay tracking yet).
        await m.addColumn(trackables, trackables.halfLifeHours);

        // Has a default value — existing rows get "mg" automatically.
        await m.addColumn(trackables, trackables.unit);

        // Non-nullable without a default can't use m.addColumn on a table
        // with existing rows, so we use raw SQL with a temporary default.
        // After this, we immediately update each row with its real palette color.
        await customStatement(
          'ALTER TABLE trackables ADD COLUMN color INTEGER NOT NULL DEFAULT 0',
        );

        // Assign colors from the palette based on creation order (by id).
        // Like: Trackable::orderBy('id')->get()->each(fn($t, $i) => ...)
        final existing = await (select(trackables)
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
        for (var i = 0; i < existing.length; i++) {
          await (update(trackables)
                ..where((t) => t.id.equals(existing[i].id)))
              .write(TrackablesCompanion(
            color: Value(trackableColorPalette[i % trackableColorPalette.length]),
          ));
        }

        // Rename amount_mg → amount. SQLite 3.25+ supports RENAME COLUMN.
        // sqlite3_flutter_libs bundles a modern SQLite, so this is safe.
        await customStatement(
          'ALTER TABLE dose_logs RENAME COLUMN amount_mg TO amount',
        );
      }
      if (from < 5) {
        // v4 → v5: Add sortOrder column to trackables for user-controlled ordering.
        // Default is 0, then we immediately set each row's sortOrder = its id
        // so existing trackables keep their insertion order.
        await m.addColumn(trackables, trackables.sortOrder);

        // Set sortOrder = id for all existing rows (preserves insertion order).
        // Like: Trackable::orderBy('id')->get()->each(fn($t, $i) => $t->update(['sort_order' => $i + 1]))
        final existing = await (select(trackables)
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
        for (var i = 0; i < existing.length; i++) {
          await (update(trackables)
                ..where((t) => t.id.equals(existing[i].id)))
              .write(TrackablesCompanion(sortOrder: Value(i + 1)));
        }
      }
      if (from < 6) {
        // v5 → v6: Add decayModel and eliminationRate columns.
        // decayModel defaults to 'none', eliminationRate is nullable.
        await m.addColumn(trackables, trackables.decayModel);
        await m.addColumn(trackables, trackables.eliminationRate);

        // Backfill: trackables that have a half-life were using exponential decay.
        // This preserves their existing behavior under the new model system.
        await customStatement(
          "UPDATE trackables SET decay_model = 'exponential' WHERE half_life_hours IS NOT NULL",
        );

        // Alcohol gets linear decay at 9 ml/hour (avg liver processing rate).
        // Also clear its half-life since linear decay uses eliminationRate instead.
        await customStatement(
          "UPDATE trackables SET decay_model = 'linear', elimination_rate = 9.0, half_life_hours = NULL WHERE name = 'Alcohol'",
        );
      }
      if (from < 7) {
        // v6 → v7: Add presets table for named dose shortcuts.
        await m.createTable(presets);
      }
      if (from < 8) {
        // v7 → v8: Add absorptionMinutes column to trackables.
        // Nullable — existing rows get NULL (instant absorption, unchanged behavior).
        await m.addColumn(trackables, trackables.absorptionMinutes);
      }
      if (from < 9) {
        // v8 → v9: Add thresholds table for named horizontal lines on charts.
        // Each trackable can have multiple thresholds (e.g., "Daily max" = 400 mg).
        await m.createTable(thresholds);
      }
      if (from < 10) {
        // v9 → v10: Add optional name column to dose_logs.
        // Stores the preset name (e.g., "Espresso") when a dose is logged via
        // a preset chip. Nullable — manually entered doses have no name.
        await m.addColumn(doseLogs, doseLogs.name);
      }
      if (from < 11) {
        // v10 → v11: Add showCumulativeLine toggle to trackables.
        // When enabled, the dashboard chart overlays a cumulative intake
        // staircase line alongside the decay curve.
        await m.addColumn(trackables, trackables.showCumulativeLine);
      }
      if (from < 12) {
        // v11 → v12: Add taper_plans table for gradual reduction schedules.
        // Each plan defines a linear ramp from startAmount to targetAmount.
        await m.createTable(taperPlans);
      }
      if (from < 13) {
        // v12 → v13: Add dashboard_widgets table — decouples dashboard layout
        // from trackable visibility. Each widget is an independent card on the
        // dashboard that shows a specific view (decay curve or taper progress)
        // of a trackable's data.
        await m.createTable(dashboardWidgets);

        // Migrate existing visible trackables to dashboard widgets.
        // Each visible trackable gets a 'decay_card' widget, preserving sortOrder.
        // This keeps the dashboard looking identical to before the migration.
        final visible = await (select(trackables)
              ..where((t) => t.isVisible.equals(true))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();

        for (final t in visible) {
          // Copy the trackable's showCumulativeLine setting into the widget's
          // config JSON, so the new widget-based rendering can read it.
          final config = t.showCumulativeLine
              ? '{"showCumulativeLine":true}'
              : '{}';
          await into(dashboardWidgets).insert(
            DashboardWidgetsCompanion.insert(
              type: 'decay_card',
              trackableId: Value(t.id),
              sortOrder: Value(t.sortOrder),
              config: Value(config),
            ),
          );
        }

        // Also add taper_progress widgets for trackables with active taper plans.
        // These go after all the decay cards (sortOrder = max + 1 and up).
        final activePlans = await (select(taperPlans)
              ..where((t) => t.isActive.equals(true)))
            .get();

        // Find the max sortOrder from the widgets we just inserted.
        var nextSort = visible.isEmpty
            ? 1
            : visible.map((t) => t.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

        for (final plan in activePlans) {
          // Only add if the trackable is visible (it already has a decay card).
          final hasWidget = visible.any((t) => t.id == plan.trackableId);
          if (hasWidget) {
            await into(dashboardWidgets).insert(
              DashboardWidgetsCompanion.insert(
                type: 'taper_progress',
                trackableId: Value(plan.trackableId),
                sortOrder: Value(nextSort),
              ),
            );
            nextSort++;
          }
        }
      }
    },
  );

  // --- Demo data seeder ---

  /// Seeds demo presets, thresholds, and dose logs so the app looks "used"
  /// on first install. Called once from main.dart, gated by a SharedPreferences
  /// flag to ensure it only runs once.
  ///
  /// Separated from onCreate so test databases stay clean — tests get the 3
  /// trackables but no extra presets, thresholds, or dose logs.
  /// Like php artisan db:seed --class=DemoSeeder.
  Future<void> seedDemoData() async {
    // Fetch the seeded trackables by name (IDs may vary between installs).
    final allTrackables = await select(trackables).get();
    final caffeine = allTrackables.where((t) => t.name == 'Caffeine').firstOrNull;
    final water = allTrackables.where((t) => t.name == 'Water').firstOrNull;
    final alcohol = allTrackables.where((t) => t.name == 'Alcohol').firstOrNull;

    // --- Caffeine presets ---
    // Common drink sizes for one-tap dose entry in the quick-add dialog.
    if (caffeine != null) {
      await into(presets).insert(PresetsCompanion.insert(
        trackableId: caffeine.id, name: 'Espresso', amount: 63, sortOrder: const Value(1),
      ));
      await into(presets).insert(PresetsCompanion.insert(
        trackableId: caffeine.id, name: 'Filter coffee', amount: 96, sortOrder: const Value(2),
      ));
      await into(presets).insert(PresetsCompanion.insert(
        trackableId: caffeine.id, name: 'Double espresso', amount: 126, sortOrder: const Value(3),
      ));
      await into(presets).insert(PresetsCompanion.insert(
        trackableId: caffeine.id, name: 'Energy drink', amount: 80, sortOrder: const Value(4),
      ));

      // Caffeine threshold — FDA-recommended daily limit for healthy adults.
      await into(thresholds).insert(ThresholdsCompanion.insert(
        trackableId: caffeine.id, name: 'Daily max', amount: 400,
      ));

      // Sample dose logs — simulate a typical day of coffee drinking.
      // Placed "today" relative to install time so the dashboard chart shows data.
      // name = preset name so log entries show "Espresso" instead of just "63 mg".
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // Morning espresso at 7:15 AM
      await into(doseLogs).insert(DoseLogsCompanion.insert(
        trackableId: caffeine.id, amount: 63, loggedAt: today.add(const Duration(hours: 7, minutes: 15)),
        name: const Value('Espresso'),
      ));
      // Mid-morning filter coffee at 10:00 AM
      await into(doseLogs).insert(DoseLogsCompanion.insert(
        trackableId: caffeine.id, amount: 96, loggedAt: today.add(const Duration(hours: 10)),
        name: const Value('Filter coffee'),
      ));
      // After-lunch espresso at 13:30
      await into(doseLogs).insert(DoseLogsCompanion.insert(
        trackableId: caffeine.id, amount: 63, loggedAt: today.add(const Duration(hours: 13, minutes: 30)),
        name: const Value('Espresso'),
      ));
    }

    // --- Water presets + sample doses ---
    if (water != null) {
      await into(presets).insert(PresetsCompanion.insert(
        trackableId: water.id, name: 'Glass', amount: 250, sortOrder: const Value(1),
      ));
      await into(presets).insert(PresetsCompanion.insert(
        trackableId: water.id, name: 'Bottle', amount: 500, sortOrder: const Value(2),
      ));

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await into(doseLogs).insert(DoseLogsCompanion.insert(
        trackableId: water.id, amount: 250, loggedAt: today.add(const Duration(hours: 7, minutes: 30)),
        name: const Value('Glass'),
      ));
      await into(doseLogs).insert(DoseLogsCompanion.insert(
        trackableId: water.id, amount: 500, loggedAt: today.add(const Duration(hours: 12)),
        name: const Value('Bottle'),
      ));
    }

    // --- Alcohol presets ---
    // Standard drink equivalents in pure alcohol ml.
    if (alcohol != null) {
      await into(presets).insert(PresetsCompanion.insert(
        trackableId: alcohol.id, name: 'Beer (330ml)', amount: 13, sortOrder: const Value(1),
      ));
      await into(presets).insert(PresetsCompanion.insert(
        trackableId: alcohol.id, name: 'Wine (150ml)', amount: 18, sortOrder: const Value(2),
      ));
    }
  }

  // --- Backup utilities ---

  /// Flush the WAL (Write-Ahead Log) into the main .sqlite file.
  ///
  /// SQLite uses WAL mode by default — writes go to a separate -wal file
  /// before being merged into the main file. If we copy taper.sqlite without
  /// checkpointing first, the copy might be missing recent writes.
  ///
  /// TRUNCATE mode = flush everything AND delete the WAL file afterward.
  /// Like running `OPTIMIZE TABLE` before a mysqldump in MySQL.
  ///
  /// Must be called before any file copy operation (export, auto-backup).
  Future<void> checkpointWal() async {
    await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  // --- Trackable queries ---

  /// Watch all trackables sorted by user-controlled sortOrder (reactive stream).
  /// Like: Trackable::orderBy('sort_order')->get()
  Stream<List<Trackable>> watchAllTrackables() {
    return (select(trackables)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// Watch only visible trackables, sorted by sortOrder.
  /// Used by the dashboard cards and Log form dropdown.
  /// Like: Trackable::where('is_visible', true)->orderBy('sort_order')->get()
  Stream<List<Trackable>> watchVisibleTrackables() {
    return (select(trackables)
          ..where((t) => t.isVisible.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// Insert a new trackable with auto-assigned color and sort order.
  /// Color cycles through the palette; sortOrder = max existing + 1.
  /// Like: $color = $palette[Trackable::count() % count($palette)]
  Future<int> insertTrackable(
    String name, {
    String unit = 'mg',
    double? halfLifeHours,
    String decayModel = 'none',
    double? eliminationRate,
    double? absorptionMinutes,
  }) async {
    // Count existing trackables to pick the next color in the palette.
    final existing = await (select(trackables)
          ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
          ..limit(1))
        .getSingleOrNull();

    // Color = count-based cycling, sortOrder = max + 1 (new items go last).
    final count = await (selectOnly(trackables)..addColumns([trackables.id]))
        .get()
        .then((rows) => rows.length);
    final nextSortOrder = (existing?.sortOrder ?? 0) + 1;

    final trackableId = await into(trackables).insert(
      TrackablesCompanion.insert(
        name: name,
        unit: Value(unit),
        halfLifeHours: Value(halfLifeHours),
        color: trackableColorPalette[count % trackableColorPalette.length],
        sortOrder: Value(nextSortOrder),
        decayModel: Value(decayModel),
        eliminationRate: Value(eliminationRate),
        absorptionMinutes: Value(absorptionMinutes),
      ),
    );

    // Auto-add a decay_card dashboard widget for the new trackable.
    // This way new trackables immediately appear on the dashboard
    // without the user having to manually add them via edit mode.
    await insertDashboardWidget('decay_card', trackableId: trackableId);

    return trackableId;
  }

  /// Update a trackable's fields.
  /// Uses named params with `Value<T>` wrappers so callers can distinguish
  /// "set halfLifeHours to null" from "don't change halfLifeHours".
  /// Like Laravel's fill() — only update fields that are explicitly passed.
  Future<int> updateTrackable(
    int id, {
    String? name,
    String? unit,
    String? decayModel,
    // Value.absent() = don't change; Value(null) = set to null; Value(5.0) = set to 5.0.
    // This three-state pattern lets the caller explicitly clear a nullable field.
    Value<double?> halfLifeHours = const Value.absent(),
    Value<double?> eliminationRate = const Value.absent(),
    Value<double?> absorptionMinutes = const Value.absent(),
    Value<bool> isVisible = const Value.absent(),
    // Color uses the same Value pattern: absent = don't change, Value(0xFF...) = set.
    Value<int> color = const Value.absent(),
    Value<bool> showCumulativeLine = const Value.absent(),
  }) {
    final companion = TrackablesCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      unit: unit != null ? Value(unit) : const Value.absent(),
      decayModel: decayModel != null ? Value(decayModel) : const Value.absent(),
      halfLifeHours: halfLifeHours,
      eliminationRate: eliminationRate,
      absorptionMinutes: absorptionMinutes,
      isVisible: isVisible,
      color: color,
      showCumulativeLine: showCumulativeLine,
    );
    return (update(trackables)..where((t) => t.id.equals(id)))
        .write(companion);
  }

  Future<int> deleteTrackable(int id) {
    return (delete(trackables)..where((t) => t.id.equals(id))).go();
  }

  /// Reorder trackables by writing sortOrder = index for each ID.
  /// Called after drag-to-reorder in the trackables screen.
  /// Uses a transaction so the reorder is atomic (all or nothing).
  /// Like: DB::transaction(fn() => collect($ids)->each(fn($id, $i) => ...))
  Future<void> reorderTrackables(List<int> orderedIds) {
    return transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(trackables)
              ..where((t) => t.id.equals(orderedIds[i])))
            .write(TrackablesCompanion(sortOrder: Value(i + 1)));
      }
    });
  }

  // --- Dose log queries ---

  /// Get a single trackable by ID (one-shot, not reactive).
  /// Used by the notification service which doesn't need stream reactivity.
  /// Like: Trackable::find($id)
  Future<Trackable?> getTrackable(int id) {
    return (select(trackables)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get doses for a trackable from [since] onward (one-shot, not reactive).
  /// Used by the notification service to calculate current active amount.
  /// Like: DoseLog::where('trackable_id', $id)->where('logged_at', '>=', $since)->get()
  Future<List<DoseLog>> getDosesSince(int trackableId, DateTime since) {
    return (select(doseLogs)
          ..where((t) =>
              t.trackableId.equals(trackableId) &
              t.loggedAt.isBiggerOrEqualValue(since))
          ..orderBy([(t) => OrderingTerm.asc(t.loggedAt)]))
        .get();
  }

  /// Get the most recent dose across ALL trackables (one-shot).
  /// Used by the log form to auto-select the last-used trackable.
  /// Like: DoseLog::latest('logged_at')->first()
  Future<DoseLog?> getLastDoseLogGlobal() {
    return (select(doseLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get the most recent dose for a trackable (one-shot, not reactive).
  /// Used by the notification service for "Repeat Last" action.
  /// Like: DoseLog::where('trackable_id', $id)->latest('logged_at')->first()
  Future<DoseLog?> getLastDose(int trackableId) {
    return (select(doseLogs)
          ..where((t) => t.trackableId.equals(trackableId))
          ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Watch doses for a single trackable from [since] onward.
  ///
  /// Used by the dashboard card provider — loads doses within the decay window
  /// (day boundary minus 5 half-lives) so still-decaying old doses are included.
  /// Like: DoseLog::where('trackable_id', $id)->where('logged_at', '>=', $since)->get()
  Stream<List<DoseLog>> watchDosesSince(int trackableId, DateTime since) {
    return (select(doseLogs)
          ..where((t) =>
              t.trackableId.equals(trackableId) &
              t.loggedAt.isBiggerOrEqualValue(since))
          ..orderBy([(t) => OrderingTerm.asc(t.loggedAt)]))
        .watch();
  }

  /// Watch the most recent dose for a trackable (for "Repeat Last" button).
  ///
  /// Returns a stream of the single most recent DoseLog, or null if none exist.
  /// The stream updates whenever doses change, so the Repeat Last button
  /// appears/disappears reactively.
  /// Like: DoseLog::where('trackable_id', $id)->latest('logged_at')->first()
  Stream<DoseLog?> watchLastDose(int trackableId) {
    return (select(doseLogs)
          ..where((t) => t.trackableId.equals(trackableId))
          ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Watch doses for a trackable between two dates (for trackable log screen).
  ///
  /// Used for the paginated history view — loads doses within a date range
  /// that expands as the user scrolls down.
  /// Like: DoseLog::where('trackable_id', $id)->whereBetween('logged_at', [$from, $to])->get()
  Stream<List<DoseLog>> watchDosesBetween(
    int trackableId,
    DateTime from,
    DateTime to,
  ) {
    return (select(doseLogs)
          ..where((t) =>
              t.trackableId.equals(trackableId) &
              t.loggedAt.isBiggerOrEqualValue(from) &
              t.loggedAt.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]))
        .watch();
  }

  /// Insert a new dose log, optionally with a preset name.
  /// [name] = preset name (e.g., "Espresso") if logged via a preset chip, null otherwise.
  /// Like: DoseLog::create(['trackable_id' => $id, 'amount' => 90, 'logged_at' => now(), 'name' => 'Espresso'])
  Future<int> insertDoseLog(int trackableId, double amount, DateTime loggedAt, {String? name}) {
    return into(doseLogs).insert(
      DoseLogsCompanion.insert(
        trackableId: trackableId,
        amount: amount,
        loggedAt: loggedAt,
        name: Value(name),
      ),
    );
  }

  /// Delete a dose log by ID.
  Future<int> deleteDoseLog(int id) {
    return (delete(doseLogs)..where((t) => t.id.equals(id))).go();
  }

  /// Update an existing dose log.
  /// Like: DoseLog::find($id)->update([...])
  /// Same pattern as updateTrackable() above — build an update query with
  /// a where clause, then .write() the new values wrapped in a Companion.
  /// [name] uses the Value pattern: absent = don't change, Value(null) = clear, Value('x') = set.
  Future<int> updateDoseLog(
    int id,
    int trackableId,
    double amount,
    DateTime loggedAt, {
    Value<String?> name = const Value.absent(),
  }) {
    return (update(doseLogs)..where((t) => t.id.equals(id)))
        .write(DoseLogsCompanion(
          trackableId: Value(trackableId),
          amount: Value(amount),
          loggedAt: Value(loggedAt),
          name: name,
        ));
  }

  // --- Preset queries ---

  /// Watch presets for a trackable, sorted alphabetically by name (reactive stream).
  /// Used by the edit trackable screen's presets list and the quick-add dialog chips.
  /// Like: Preset::where('trackable_id', $id)->orderBy('name')->get()
  Stream<List<Preset>> watchPresets(int trackableId) {
    return (select(presets)
          ..where((t) => t.trackableId.equals(trackableId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Get presets for a trackable (one-shot, not reactive).
  /// Used by callers that need presets before opening a dialog.
  /// Like: Preset::where('trackable_id', $id)->orderBy('name')->get()
  Future<List<Preset>> getPresets(int trackableId) {
    return (select(presets)
          ..where((t) => t.trackableId.equals(trackableId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  /// Insert a new preset with auto-assigned sortOrder (max + 1).
  /// Like: $maxSort = Preset::where('trackable_id', $id)->max('sort_order');
  ///       Preset::create([..., 'sort_order' => $maxSort + 1])
  Future<int> insertPreset(int trackableId, String name, double amount) async {
    // Find the current max sortOrder for this trackable's presets.
    final existing = await (select(presets)
          ..where((t) => t.trackableId.equals(trackableId))
          ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
          ..limit(1))
        .getSingleOrNull();
    final nextSort = (existing?.sortOrder ?? 0) + 1;

    return into(presets).insert(
      PresetsCompanion.insert(
        trackableId: trackableId,
        name: name,
        amount: amount,
        sortOrder: Value(nextSort),
      ),
    );
  }

  /// Update a preset's name and/or amount.
  /// Like: Preset::find($id)->update([...])
  Future<int> updatePreset(int id, {String? name, double? amount}) {
    final companion = PresetsCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      amount: amount != null ? Value(amount) : const Value.absent(),
    );
    return (update(presets)..where((t) => t.id.equals(id))).write(companion);
  }

  /// Delete a preset by ID.
  /// Like: Preset::destroy($id)
  Future<int> deletePreset(int id) {
    return (delete(presets)..where((t) => t.id.equals(id))).go();
  }

  // --- Threshold queries ---

  /// Watch thresholds for a trackable, sorted by amount ascending (reactive stream).
  /// Used by the card data provider and edit screen.
  /// Like: Threshold::where('trackable_id', $id)->orderBy('amount')->get()
  Stream<List<Threshold>> watchThresholds(int trackableId) {
    return (select(thresholds)
          ..where((t) => t.trackableId.equals(trackableId))
          ..orderBy([(t) => OrderingTerm.asc(t.amount)]))
        .watch();
  }

  /// Get thresholds for a trackable (one-shot, not reactive).
  /// Like: Threshold::where('trackable_id', $id)->orderBy('amount')->get()
  Future<List<Threshold>> getThresholds(int trackableId) {
    return (select(thresholds)
          ..where((t) => t.trackableId.equals(trackableId))
          ..orderBy([(t) => OrderingTerm.asc(t.amount)]))
        .get();
  }

  /// Insert a new threshold for a trackable.
  /// Like: Threshold::create(['trackable_id' => $id, 'name' => 'Daily max', 'amount' => 400])
  Future<int> insertThreshold(int trackableId, String name, double amount) {
    return into(thresholds).insert(
      ThresholdsCompanion.insert(
        trackableId: trackableId,
        name: name,
        amount: amount,
      ),
    );
  }

  /// Update a threshold's name and/or amount.
  /// Like: Threshold::find($id)->update([...])
  Future<int> updateThreshold(int id, {String? name, double? amount}) {
    final companion = ThresholdsCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      amount: amount != null ? Value(amount) : const Value.absent(),
    );
    return (update(thresholds)..where((t) => t.id.equals(id))).write(companion);
  }

  /// Delete a threshold by ID.
  /// Like: Threshold::destroy($id)
  Future<int> deleteThreshold(int id) {
    return (delete(thresholds)..where((t) => t.id.equals(id))).go();
  }

  // --- Taper plan queries ---

  /// Watch the active taper plan for a trackable (reactive stream).
  /// Returns null if no active plan exists.
  /// Used by the dashboard card to show today's target.
  /// Like: TaperPlan::where('trackable_id', $id)->where('is_active', true)->first()
  Stream<TaperPlan?> watchActiveTaperPlan(int trackableId) {
    return (select(taperPlans)
          ..where((t) =>
              t.trackableId.equals(trackableId) & t.isActive.equals(true))
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Watch all taper plans for a trackable, newest first (reactive stream).
  /// Used by the edit trackable screen to list plan history.
  /// Like: TaperPlan::where('trackable_id', $id)->orderByDesc('start_date')->get()
  Stream<List<TaperPlan>> watchTaperPlans(int trackableId) {
    return (select(taperPlans)
          ..where((t) => t.trackableId.equals(trackableId))
          ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
        .watch();
  }

  /// Insert a new taper plan, atomically deactivating any existing active plan.
  ///
  /// Uses a transaction so the deactivation + insertion happens atomically —
  /// there's never a moment where two plans are active simultaneously.
  /// Like a DB::transaction in Laravel that wraps a deactivate + insert.
  ///
  /// Returns the new plan's auto-increment ID.
  Future<int> insertTaperPlan(
    int trackableId,
    double startAmount,
    double targetAmount,
    DateTime startDate,
    DateTime endDate,
  ) {
    return transaction(() async {
      // Deactivate any existing active plan for this trackable.
      // UPDATE taper_plans SET is_active = 0 WHERE trackable_id = ? AND is_active = 1
      await (update(taperPlans)
            ..where((t) =>
                t.trackableId.equals(trackableId) & t.isActive.equals(true)))
          .write(const TaperPlansCompanion(isActive: Value(false)));

      // Insert the new active plan.
      return into(taperPlans).insert(
        TaperPlansCompanion.insert(
          trackableId: trackableId,
          startAmount: startAmount,
          targetAmount: targetAmount,
          startDate: startDate,
          endDate: endDate,
        ),
      );
    });
  }

  /// Delete a taper plan by ID.
  /// Like: TaperPlan::destroy($id)
  Future<int> deleteTaperPlan(int id) {
    return (delete(taperPlans)..where((t) => t.id.equals(id))).go();
  }

  // --- Dashboard widget queries ---

  /// Watch all dashboard widgets, ordered by sortOrder (reactive stream).
  /// Used by the dashboard screen to know which cards to render and in what order.
  /// Like: DashboardWidget::orderBy('sort_order')->get()
  Stream<List<DashboardWidget>> watchDashboardWidgets() {
    return (select(dashboardWidgets)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// Insert a new dashboard widget with auto-assigned sortOrder (max + 1).
  /// Returns the new widget's auto-increment ID.
  /// Like: $maxSort = DashboardWidget::max('sort_order'); DashboardWidget::create([...])
  Future<int> insertDashboardWidget(
    String type, {
    int? trackableId,
    String config = '{}',
  }) async {
    // Find the current max sortOrder to append the new widget at the end.
    final last = await (select(dashboardWidgets)
          ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
          ..limit(1))
        .getSingleOrNull();
    final nextSort = (last?.sortOrder ?? 0) + 1;

    return into(dashboardWidgets).insert(
      DashboardWidgetsCompanion.insert(
        type: type,
        trackableId: Value(trackableId),
        sortOrder: Value(nextSort),
        config: Value(config),
      ),
    );
  }

  /// Delete a dashboard widget by ID.
  /// Like: DashboardWidget::destroy($id)
  Future<int> deleteDashboardWidget(int id) {
    return (delete(dashboardWidgets)..where((t) => t.id.equals(id))).go();
  }

  /// Reorder dashboard widgets by writing sortOrder = index for each ID.
  /// Called after drag-to-reorder in the dashboard's edit mode.
  /// Same transaction-based pattern as reorderTrackables().
  /// Like: DB::transaction(fn() => collect($ids)->each(fn($id, $i) => ...))
  Future<void> reorderDashboardWidgets(List<int> orderedIds) {
    return transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(dashboardWidgets)
              ..where((t) => t.id.equals(orderedIds[i])))
            .write(DashboardWidgetsCompanion(sortOrder: Value(i + 1)));
      }
    });
  }

  /// Update a dashboard widget's config JSON.
  /// Used to toggle per-widget settings (like showCumulativeLine).
  /// Like: DashboardWidget::find($id)->update(['config' => $config])
  Future<int> updateDashboardWidgetConfig(int id, String config) {
    return (update(dashboardWidgets)..where((t) => t.id.equals(id)))
        .write(DashboardWidgetsCompanion(config: Value(config)));
  }

  /// Watch recent dose logs (last 50), newest first, with trackable name.
  /// Returns a stream of (DoseLog, Trackable) pairs — like an Eloquent eager load:
  ///   DoseLog::with('trackable')->latest('logged_at')->limit(50)->get()
  ///
  /// The join gives us the trackable name alongside each dose log so we
  /// don't need a separate query. TypedResult lets us pull both tables' data.
  Stream<List<DoseLogWithTrackable>> watchRecentDoseLogs() {
    final query = select(doseLogs).join([
      // innerJoin = INNER JOIN dose_logs ON dose_logs.trackable_id = trackables.id
      // Like DoseLog::join('trackables', 'trackables.id', '=', 'dose_logs.trackable_id')
      innerJoin(trackables, trackables.id.equalsExp(doseLogs.trackableId)),
    ]);

    query
      ..orderBy([OrderingTerm.desc(doseLogs.loggedAt)])
      ..limit(50);

    // map() transforms each joined row into our simple data class.
    return query.watch().map((rows) {
      return rows.map((row) {
        return DoseLogWithTrackable(
          doseLog: row.readTable(doseLogs),
          trackable: row.readTable(trackables),
        );
      }).toList();
    });
  }
}

/// Simple data class to hold a dose log with its trackable.
/// Like a Laravel resource/DTO that combines the relationship:
///   ['dose_log' => $doseLog, 'trackable' => $doseLog->trackable]
class DoseLogWithTrackable {
  final DoseLog doseLog;
  final Trackable trackable;

  DoseLogWithTrackable({required this.doseLog, required this.trackable});
}
