import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:taper/data/database.dart';

/// Creates an in-memory AppDatabase for testing.
///
/// Like Laravel's RefreshDatabase trait with SQLite :memory: —
/// each test gets a fresh, empty database that's destroyed when done.
/// No files on disk, no leftover state between tests.
///
/// Usage:
///   final db = createTestDatabase();
///   // ... use db ...
///   await db.close();
AppDatabase createTestDatabase() {
  // Suppress the "multiple databases" warning — we intentionally create
  // a fresh DB per test, which is fine since each uses its own in-memory SQLite.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  return AppDatabase.forTesting(NativeDatabase.memory());
}
