import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// Code generator output — run: dart run build_runner build --delete-conflicting-outputs
part 'database.g.dart';

/// Substances table.
/// Laravel equivalent: Schema::create('substances', ...) + Eloquent model.
class Substances extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
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

  // real() = REAL column in SQLite, stores doubles. Like $table->double('amount_mg').
  RealColumn get amountMg => real()();

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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // onCreate = fresh install. Creates all tables and seeds data.
    onCreate: (Migrator m) async {
      await m.createAll();
      await into(substances).insert(
        SubstancesCompanion.insert(name: 'Caffeine'),
      );
    },

    // onUpgrade = existing install. Runs when schemaVersion increases.
    // Like Laravel's php artisan migrate — runs only the new migrations.
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // v1 → v2: add the dose_logs table.
        await m.createTable(doseLogs);
      }
    },
  );

  // --- Substance queries ---

  /// Watch all substances sorted by name (reactive stream).
  Stream<List<Substance>> watchAllSubstances() {
    return (select(substances)..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<int> insertSubstance(String name) {
    return into(substances).insert(
      SubstancesCompanion.insert(name: name),
    );
  }

  Future<int> updateSubstance(int id, String newName) {
    return (update(substances)..where((t) => t.id.equals(id)))
        .write(SubstancesCompanion(name: Value(newName)));
  }

  Future<int> deleteSubstance(int id) {
    return (delete(substances)..where((t) => t.id.equals(id))).go();
  }

  // --- Dose log queries ---

  /// Insert a new dose log.
  /// Like: DoseLog::create(['substance_id' => $id, 'amount_mg' => 90, 'logged_at' => now()])
  Future<int> insertDoseLog(int substanceId, double amountMg, DateTime loggedAt) {
    return into(doseLogs).insert(
      DoseLogsCompanion.insert(
        substanceId: substanceId,
        amountMg: amountMg,
        loggedAt: loggedAt,
      ),
    );
  }

  /// Delete a dose log by ID.
  Future<int> deleteDoseLog(int id) {
    return (delete(doseLogs)..where((t) => t.id.equals(id))).go();
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
