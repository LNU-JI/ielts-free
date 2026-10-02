/// Test helpers for opening throwaway SQLite databases with the **real** schema.
///
/// Data / integration tests must never touch the production database files, so
/// this helper opens either an in-memory database or a database inside a fresh
/// temporary directory, applying the real migration scripts so the tests
/// exercise exactly the schema the app ships
/// (docs/ARCHITECTURE-v0.1.md §2.1, §4).
///
/// The desktop test runner has no `sqflite` platform channel, so the FFI factory
/// must be installed once per test binary ([initTestDatabaseFactory]).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'package:ielts_free/core/database/migrations.dart';

/// Installs the FFI SQLite factory. Call once from `setUpAll`.
void initTestDatabaseFactory() {
  ffi.sqfliteFfiInit();
  databaseFactory = ffi.databaseFactoryFfi;
}

/// The in-memory database path understood by sqflite.
const String kInMemoryPath = ':memory:';

/// Opens an empty in-memory user database migrated up to [version].
Future<Database> openInMemoryUserDb({int version = 1}) =>
    databaseFactory.openDatabase(kInMemoryPath, options: userDbOptions(version));

/// Opens a user database at [path] migrated up to [version].
///
/// Re-opening the same path with a higher [version] triggers `onUpgrade`, which
/// is exactly what the migration test needs.
Future<Database> openUserDbAt(String path, {int version = 1}) =>
    databaseFactory.openDatabase(path, options: userDbOptions(version));

/// The `OpenDatabaseOptions` used by the app's [AppDatabase] (migrations wired).
OpenDatabaseOptions userDbOptions(int version) => OpenDatabaseOptions(
      version: version,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (Database db, int newVersion) =>
          runMigrations(db, from: 0, to: newVersion),
      onUpgrade: (Database db, int oldVersion, int newVersion) =>
          runMigrations(db, from: oldVersion, to: newVersion),
    );

/// Creates a fresh temporary directory for a file-backed test database.
Directory createTestTempDir() =>
    Directory.systemTemp.createTempSync('ielts_free_test_');

/// Deletes [dir] recursively, ignoring failures.
void deleteTestTempDir(Directory dir) {
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
}

/// Joins [name] onto [dir]'s path.
String tempFilePath(Directory dir, String name) => p.join(dir.path, name);
