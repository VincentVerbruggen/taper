import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// Code generator output — run: dart run build_runner build --delete-conflicting-outputs
part 'database.g.dart';

/// 10 distinct colors for auto-assigning to substances, stored as ARGB ints.
/// These will be used for chart lines in the decay curve (Milestone 4).
/// Colors are spread across the hue wheel for maximum contrast.
/// Like a Tailwind color palette: ['red-500', 'blue-500', 'green-500', ...].
const substanceColorPalette = [
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

/// Substances table.
/// Laravel equivalent: Schema::create('substances', ...) + Eloquent model.
class Substances extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  // Whether this substance is the "default" in the Log form dropdown.
  // Only one substance can be main at a time — like a radio button.
  // withDefault(false) makes it optional in insert() calls, so existing
  // code that just passes a name keeps working.
  // Laravel equivalent: $table->boolean('is_main')->default(false)
  BoolColumn get isMain => boolean().withDefault(const Constant(false))();

  // Whether this substance appears in the Log form dropdown.
  // Hidden substances keep their dose history but don't clutter the UI.
  // Defaults to true so new substances are visible immediately.
  // Laravel equivalent: $table->boolean('is_visible')->default(true)
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();

  // Biological half-life in hours (e.g., 5.0 for caffeine).
  // Nullable: null means no decay tracking (e.g., Water has no half-life).
  // Used by the decay curve chart to calculate how much is still active.
  // Laravel equivalent: $table->double('half_life_hours')->nullable()
  RealColumn get halfLifeHours => real().nullable()();

  // Unit of measurement for doses (e.g., "mg", "ml", "IU").
  // Free text, defaults to "mg". Displayed in the Log form suffix and
  // recent logs list. Stored on the substance, not the dose log.
  // Laravel equivalent: $table->string('unit')->default('mg')
  TextColumn get unit => text().withDefault(const Constant('mg'))();

  // Auto-assigned color from substanceColorPalette (ARGB int).
  // Used for chart lines in the decay curve. No user-facing picker yet.
  // Non-nullable — always explicitly set during insert.
  // Laravel equivalent: $table->unsignedInteger('color')
  IntColumn get color => integer()();
}

/// Dose logs table — records each time a user takes a substance.
///
/// Laravel equivalent:
///   Schema::create('dose_logs', function (Blueprint $table) {
///       $table->id();
///       $table->foreignId('substance_id')->constrained()->cascadeOnDelete();
///       $table->double('amount_mg');
///       $table->dateTime('logged_at');
///   });
///
/// references() sets up a foreign key constraint — like $table->foreignId()->constrained().
/// When a substance is deleted, all its dose logs are cascade-deleted too.
class DoseLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  // FK to substances table. references() = $table->foreignId()->constrained().
  IntColumn get substanceId => integer().references(Substances, #id)();

  // real() = REAL column in SQLite, stores doubles.
  // Renamed from amountMg — the unit now comes from the substance table.
  // Like $table->double('amount').
  RealColumn get amount => real()();

  // dateTime() stores as integer (epoch seconds) in SQLite.
  // Like $table->dateTime('logged_at').
  DateTimeColumn get loggedAt => dateTime()();
}

/// AppDatabase = the database singleton.
/// Like DatabaseServiceProvider + config/database.php in Laravel.
@DriftDatabase(tables: [Substances, DoseLogs])
class AppDatabase extends _$AppDatabase {
  // Default constructor uses platform-specific SQLite via drift_flutter.
  AppDatabase() : super(driftDatabase(name: 'taper'));

  // Named constructor for tests — accepts any QueryExecutor (e.g., in-memory DB).
  // Like Laravel's DB_CONNECTION=sqlite :memory: in phpunit.xml.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // onCreate = fresh install. Creates all tables and seeds data.
    // Seeds three substances so users see visibility/main features immediately.
    onCreate: (Migrator m) async {
      await m.createAll();

      // Caffeine: main + visible — the default substance in the Log form.
      // halfLifeHours=5.0 = caffeine's biological half-life (used for decay curve).
      await into(substances).insert(
        SubstancesCompanion.insert(
          name: 'Caffeine',
          isMain: const Value(true),
          halfLifeHours: const Value(5.0),
          unit: const Value('mg'),
          color: substanceColorPalette[0],
        ),
      );
      // Water: visible but not main — no half-life (no decay tracking).
      await into(substances).insert(
        SubstancesCompanion.insert(
          name: 'Water',
          halfLifeHours: const Value(null),
          unit: const Value('ml'),
          color: substanceColorPalette[1],
        ),
      );
      // Alcohol: hidden — won't appear in Log dropdown, but data preserved.
      // halfLifeHours=4.0 = alcohol's approximate biological half-life.
      await into(substances).insert(
        SubstancesCompanion.insert(
          name: 'Alcohol',
          isVisible: const Value(false),
          halfLifeHours: const Value(4.0),
          unit: const Value('ml'),
          color: substanceColorPalette[2],
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
        // v2 → v3: add isMain and isVisible columns to substances.
        // m.addColumn() generates: ALTER TABLE substances ADD COLUMN is_main INTEGER NOT NULL DEFAULT 0
        // Existing rows get the default value automatically — like Laravel's migration with ->default().
        await m.addColumn(substances, substances.isMain);
        await m.addColumn(substances, substances.isVisible);

        // Seed Water and Alcohol for existing installs too, so they have
        // something to see the visibility difference with.
        await into(substances).insert(
          SubstancesCompanion.insert(name: 'Water', color: 0),
        );
        await into(substances).insert(
          SubstancesCompanion.insert(
            name: 'Alcohol',
            isVisible: const Value(false),
            color: 0,
          ),
        );
      }
      if (from < 4) {
        // v3 → v4: Add halfLifeHours, unit, and color to substances;
        // rename amount_mg → amount in dose_logs.

        // Nullable column — existing rows get NULL (no decay tracking yet).
        await m.addColumn(substances, substances.halfLifeHours);

        // Has a default value — existing rows get "mg" automatically.
        await m.addColumn(substances, substances.unit);

        // Non-nullable without a default can't use m.addColumn on a table
        // with existing rows, so we use raw SQL with a temporary default.
        // After this, we immediately update each row with its real palette color.
        await customStatement(
          'ALTER TABLE substances ADD COLUMN color INTEGER NOT NULL DEFAULT 0',
        );

        // Assign colors from the palette based on creation order (by id).
        // Like: Substance::orderBy('id')->get()->each(fn($s, $i) => ...)
        final existing = await (select(substances)
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
        for (var i = 0; i < existing.length; i++) {
          await (update(substances)
                ..where((t) => t.id.equals(existing[i].id)))
              .write(SubstancesCompanion(
            color: Value(substanceColorPalette[i % substanceColorPalette.length]),
          ));
        }

        // Rename amount_mg → amount. SQLite 3.25+ supports RENAME COLUMN.
        // sqlite3_flutter_libs bundles a modern SQLite, so this is safe.
        await customStatement(
          'ALTER TABLE dose_logs RENAME COLUMN amount_mg TO amount',
        );
      }
    },
  );

  // --- Substance queries ---

  /// Watch all substances sorted by name (reactive stream).
  Stream<List<Substance>> watchAllSubstances() {
    return (select(substances)..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Watch only visible substances, sorted by name.
  /// Used by the Log form dropdown — hidden substances don't appear.
  /// Like: Substance::where('is_visible', true)->orderBy('name')->get()
  Stream<List<Substance>> watchVisibleSubstances() {
    return (select(substances)
          ..where((t) => t.isVisible.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Set a substance as the "main" (default) in the Log form.
  /// Uses a transaction to ensure only one substance is main at a time —
  /// first unset all, then set the target. Like a radio button group.
  ///
  /// Laravel equivalent:
  ///   DB::transaction(function () use ($id) {
  ///       Substance::query()->update(['is_main' => false]);
  ///       Substance::find($id)->update(['is_main' => true]);
  ///   });
  Future<void> setMainSubstance(int id) {
    return transaction(() async {
      // Clear all isMain flags first.
      await update(substances).write(
        const SubstancesCompanion(isMain: Value(false)),
      );
      // Set the target substance as main.
      await (update(substances)..where((t) => t.id.equals(id)))
          .write(const SubstancesCompanion(isMain: Value(true)));
    });
  }

  /// Toggle a substance's visibility. When hiding (isVisible = false),
  /// also clears isMain — a hidden substance can't be the default in the Log form.
  ///
  /// Laravel equivalent:
  ///   DB::transaction(function () use ($id, $visible) {
  ///       $substance = Substance::find($id);
  ///       $substance->is_visible = $visible;
  ///       if (!$visible) $substance->is_main = false;
  ///       $substance->save();
  ///   });
  Future<void> toggleSubstanceVisibility(int id, bool isVisible) {
    return transaction(() async {
      final companion = isVisible
          ? SubstancesCompanion(isVisible: Value(isVisible))
          : SubstancesCompanion(
              isVisible: Value(isVisible),
              isMain: const Value(false), // Can't be main if hidden
            );
      await (update(substances)..where((t) => t.id.equals(id)))
          .write(companion);
    });
  }

  /// Insert a new substance with auto-assigned color from the palette.
  /// Color is assigned using the current substance count % palette length,
  /// so colors cycle through the palette as substances are added.
  /// Like: $color = $palette[Substance::count() % count($palette)]
  Future<int> insertSubstance(
    String name, {
    String unit = 'mg',
    double? halfLifeHours,
  }) async {
    // Count existing substances to pick the next color in the palette.
    final count = await (selectOnly(substances)..addColumns([substances.id]))
        .get()
        .then((rows) => rows.length);

    return into(substances).insert(
      SubstancesCompanion.insert(
        name: name,
        unit: Value(unit),
        halfLifeHours: Value(halfLifeHours),
        color: substanceColorPalette[count % substanceColorPalette.length],
      ),
    );
  }

  /// Update a substance's name, unit, and/or half-life.
  /// Uses named params with `Value<T>` wrappers so callers can distinguish
  /// "set halfLifeHours to null" from "don't change halfLifeHours".
  /// Like Laravel's fill() — only update fields that are explicitly passed.
  Future<int> updateSubstance(
    int id, {
    String? name,
    String? unit,
    // Value.absent() = don't change; Value(null) = set to null; Value(5.0) = set to 5.0.
    // This three-state pattern lets the caller explicitly clear a nullable field.
    Value<double?> halfLifeHours = const Value.absent(),
  }) {
    final companion = SubstancesCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      unit: unit != null ? Value(unit) : const Value.absent(),
      halfLifeHours: halfLifeHours,
    );
    return (update(substances)..where((t) => t.id.equals(id)))
        .write(companion);
  }

  Future<int> deleteSubstance(int id) {
    return (delete(substances)..where((t) => t.id.equals(id))).go();
  }

  // --- Dose log queries ---

  /// Insert a new dose log.
  /// Like: DoseLog::create(['substance_id' => $id, 'amount' => 90, 'logged_at' => now()])
  Future<int> insertDoseLog(int substanceId, double amount, DateTime loggedAt) {
    return into(doseLogs).insert(
      DoseLogsCompanion.insert(
        substanceId: substanceId,
        amount: amount,
        loggedAt: loggedAt,
      ),
    );
  }

  /// Delete a dose log by ID.
  Future<int> deleteDoseLog(int id) {
    return (delete(doseLogs)..where((t) => t.id.equals(id))).go();
  }

  /// Update an existing dose log.
  /// Like: DoseLog::find($id)->update([...])
  /// Same pattern as updateSubstance() above — build an update query with
  /// a where clause, then .write() the new values wrapped in a Companion.
  Future<int> updateDoseLog(int id, int substanceId, double amount, DateTime loggedAt) {
    return (update(doseLogs)..where((t) => t.id.equals(id)))
        .write(DoseLogsCompanion(
          substanceId: Value(substanceId),
          amount: Value(amount),
          loggedAt: Value(loggedAt),
        ));
  }

  /// Watch recent dose logs (last 50), newest first, with substance name.
  /// Returns a stream of (DoseLog, Substance) pairs — like an Eloquent eager load:
  ///   DoseLog::with('substance')->latest('logged_at')->limit(50)->get()
  ///
  /// The join gives us the substance name alongside each dose log so we
  /// don't need a separate query. TypedResult lets us pull both tables' data.
  Stream<List<DoseLogWithSubstance>> watchRecentDoseLogs() {
    final query = select(doseLogs).join([
      // innerJoin = INNER JOIN dose_logs ON dose_logs.substance_id = substances.id
      // Like DoseLog::join('substances', 'substances.id', '=', 'dose_logs.substance_id')
      innerJoin(substances, substances.id.equalsExp(doseLogs.substanceId)),
    ]);

    query
      ..orderBy([OrderingTerm.desc(doseLogs.loggedAt)])
      ..limit(50);

    // map() transforms each joined row into our simple data class.
    return query.watch().map((rows) {
      return rows.map((row) {
        return DoseLogWithSubstance(
          doseLog: row.readTable(doseLogs),
          substance: row.readTable(substances),
        );
      }).toList();
    });
  }
}

/// Simple data class to hold a dose log with its substance.
/// Like a Laravel resource/DTO that combines the relationship:
///   ['dose_log' => $doseLog, 'substance' => $doseLog->substance]
class DoseLogWithSubstance {
  final DoseLog doseLog;
  final Substance substance;

  DoseLogWithSubstance({required this.doseLog, required this.substance});
}
