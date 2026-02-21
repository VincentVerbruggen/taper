import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// "part" tells Drift's code generator to output generated code into database.g.dart.
// You define the schema, the tool generates the SQL/boilerplate — like artisan make:migration.
// Run: dart run build_runner build --delete-conflicting-outputs
part 'database.g.dart';

/// Drift table definition = Laravel migration + Eloquent model combined.
///
/// In Laravel you'd write:
///   Schema::create('substances', function (Blueprint $table) {
///       $table->id();
///       $table->string('name');
///   });
///
/// In Drift, you define a class extending Table. Each getter returns a column
/// builder — like $table->string('name'). The generated "Substance" data class
/// (in database.g.dart) is like an Eloquent Model instance — one row with typed fields.
class Substances extends Table {
  // autoIncrement() = $table->id() in Laravel.
  // Creates INTEGER PRIMARY KEY AUTOINCREMENT.
  IntColumn get id => integer().autoIncrement()();

  // text() = $table->string('name') in Laravel.
  // The trailing () "builds" the column (builder pattern).
  TextColumn get name => text()();
}

/// AppDatabase = the database singleton.
///
/// Like your DatabaseServiceProvider + config/database.php in Laravel.
/// It defines which tables exist and provides query methods (Eloquent scopes).
///
/// @DriftDatabase tells the code generator which tables to include.
/// After build_runner runs, it generates _$AppDatabase with all the wiring —
/// similar to how artisan generates migration files from your schema.
@DriftDatabase(tables: [Substances])
class AppDatabase extends _$AppDatabase {
  // driftDatabase() from drift_flutter handles the platform-specific SQLite
  // loading automatically (Android, iOS, desktop, web). No manual file paths needed.
  // Like Laravel's DB_CONNECTION=sqlite — it just works.
  AppDatabase() : super(driftDatabase(name: 'taper'));

  // schemaVersion = migration version number. Bump when you change tables
  // and add migration logic. Like the timestamp in Laravel migration filenames.
  @override
  int get schemaVersion => 1;

  // MigrationStrategy = Laravel's DatabaseSeeder.
  // onCreate runs once when the database file is first created on a fresh install.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll(); // Run all CREATE TABLE statements

      // Seed default data — like php artisan db:seed.
      // into() + insert() = Substance::create(['name' => 'Caffeine'])
      await into(substances).insert(
        SubstancesCompanion.insert(name: 'Caffeine'),
      );
    },
  );

  // --- DAO methods (Eloquent query scopes in Laravel terms) ---
  // In the old Kotlin project, these lived in SubstanceDao.kt.
  // For Milestone 1 with one table, we keep them here and split in Milestone 2.

  /// Watch all substances sorted by name.
  /// Returns a Stream — like a Livewire reactive property backed by a DB query.
  /// Whenever a substance is inserted/updated/deleted, this stream automatically
  /// emits the fresh list. No manual refresh needed.
  ///
  /// Laravel: Substance::orderBy('name')->get() ...but reactive (auto-updates).
  Stream<List<Substance>> watchAllSubstances() {
    return (select(substances)..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Insert a new substance. Returns the auto-generated ID.
  /// Like: Substance::create(['name' => $name])->id
  Future<int> insertSubstance(String name) {
    return into(substances).insert(
      SubstancesCompanion.insert(name: name),
    );
  }

  /// Update a substance's name.
  /// Like: Substance::find($id)->update(['name' => $newName])
  ///
  /// Value(newName) means "set this column to newName".
  /// Absent columns are left unchanged — like $model->update(['name' => $newName]).
  /// Returns the number of rows affected (should be 1).
  Future<int> updateSubstance(int id, String newName) {
    return (update(substances)..where((t) => t.id.equals(id)))
        .write(SubstancesCompanion(name: Value(newName)));
  }

  /// Delete a substance by ID.
  /// Like: Substance::destroy($id)
  Future<int> deleteSubstance(int id) {
    return (delete(substances)..where((t) => t.id.equals(id))).go();
  }
}
