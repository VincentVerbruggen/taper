import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:taper/data/database.dart';

/// databaseProvider = the app's database singleton.
///
/// Like Laravel's `$app->singleton()`:
///   `$this->app->singleton(AppDatabase::class, fn() => new AppDatabase())`;
///
/// Once created, it lives forever. Every widget that needs the database
/// calls ref.read(databaseProvider) or ref.watch(databaseProvider).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();

  // ref.onDispose = cleanup when provider is destroyed.
  // Like __destruct() in PHP — close the DB connection.
  ref.onDispose(() => db.close());

  return db;
});

/// substancesProvider = a reactive stream of all substances.
///
/// Like a Livewire computed property backed by a DB query:
///   public function getSubstancesProperty() {
///       return Substance::orderBy('name')->get();
///   }
///
/// Except it's push-based, not polling. When you insert/update/delete a substance,
/// Drift's .watch() automatically emits the fresh list, and every widget
/// watching this provider re-renders instantly.
///
/// The AsyncValue wrapper handles three states:
///   - AsyncLoading (spinner while DB query runs first time)
///   - AsyncData (the substance list)
///   - AsyncError (if something goes wrong)
final substancesProvider = StreamProvider<List<Substance>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllSubstances();
});
