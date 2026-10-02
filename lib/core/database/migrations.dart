/// Versioned, idempotent, append-only database migrations.
///
/// ## Guarantees (docs/BRIEF.md §71–75, NFR-30)
///
/// - Migration steps only ever `CREATE TABLE IF NOT EXISTS`,
///   `ALTER TABLE ... ADD COLUMN` or `CREATE INDEX IF NOT EXISTS`.
/// - No step ever `DROP`s a table or deletes rows.
/// - Before an upgrade the current database is backed up (see [vacuumBackup]);
///   a failed upgrade can therefore be rolled back by restoring the copy.
///
/// The schema version constant lives in `lib/app/constants.dart`
/// ([kUserDbVersion]) — this file deliberately does not redefine it so there is
/// a single source of truth.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/database/schema_user.dart';

/// The versioned migration steps, keyed by the version they produce.
///
/// - `1`: v0 → v1 — create the entire initial user schema.
/// - `2`: v1 → v2 — **example only** (see the note below).
///
/// The `2` entry is intentionally present so the T05 migration test can prove a
/// real v1 → v2 upgrade preserves user data. It is **not** reachable in normal
/// use because [kUserDbVersion] stays at `1`; it is exercised only by calling
/// [runMigrations] with `to: 2` directly from a test.
final Map<int, List<String>> migrationSteps = <int, List<String>>{
  1: userSchemaStatements(),
  2: <String>[
    // Example additive change: new profile columns with safe defaults.
    // `ADD COLUMN` with a NOT NULL DEFAULT is backward compatible and keeps
    // every existing row intact.
    "ALTER TABLE user_profile ADD COLUMN font_scale REAL NOT NULL DEFAULT 1.0",
    "ALTER TABLE user_profile ADD COLUMN theme_mode TEXT NOT NULL DEFAULT 'system'",
    // Example additive index; speeds up per-skill correctness lookups.
    'CREATE INDEX IF NOT EXISTS idx_ua_user_correct ON user_answers(user_id, is_correct)',
  ],
};

/// Applies every migration step in `(from, to]` in ascending order.
///
/// Safe to call with `from == to` (no-op) and idempotent for a fresh database
/// (`from == 0`) because every statement is guarded by `IF NOT EXISTS`.
Future<void> runMigrations(
  Database db, {
  required int from,
  required int to,
}) async {
  for (int version = from + 1; version <= to; version++) {
    final List<String> steps = migrationSteps[version] ?? const <String>[];
    for (final String statement in steps) {
      await db.execute(statement);
    }
  }
}

/// Builds the timestamped file name used for a pre-upgrade backup.
String backupFileName(String sourcePath, DateTime nowUtc) {
  final String base = p.basenameWithoutExtension(sourcePath);
  final String stamp = nowUtc
      .toUtc()
      .toIso8601String()
      .replaceAll(':', '')
      .replaceAll('.', '')
      .replaceAll('-', '');
  return '${base}_backup_$stamp.db';
}

/// Creates a consistent copy of the SQLite file at [sourcePath] inside
/// [backupDirPath] using `VACUUM INTO`.
///
/// `VACUUM INTO` must **not** run inside a transaction, so this helper opens its
/// own connection and is therefore called *before* the versioned database is
/// opened (see `app_database.dart`). Returns the created backup file path.
Future<String> vacuumBackup({
  required String sourcePath,
  required String backupDirPath,
  DateTime? now,
}) async {
  final Directory dir = Directory(backupDirPath);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final String target = p.join(
    dir.path,
    backupFileName(sourcePath, now ?? DateTime.now()),
  );

  final Database db = await databaseFactory.openDatabase(
    sourcePath,
    options: OpenDatabaseOptions(readOnly: false),
  );
  try {
    await db.execute('VACUUM INTO ${_quoteSqlString(target)}');
  } finally {
    await db.close();
  }
  return target;
}

/// Fallback backup that copies the file bytes directly.
///
/// Used when `VACUUM INTO` is unavailable on the current SQLite build. A plain
/// copy is safe here because it happens before the database is opened for the
/// upgrade, so no write transaction is in flight.
Future<String> fileCopyBackup({
  required String sourcePath,
  required String backupDirPath,
  DateTime? now,
}) async {
  final Directory dir = Directory(backupDirPath);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final String target = p.join(
    dir.path,
    backupFileName(sourcePath, now ?? DateTime.now()),
  );
  await File(sourcePath).copy(target);
  return target;
}

/// Quotes a value for inline use in a SQLite string literal.
String _quoteSqlString(String value) => "'${value.replaceAll("'", "''")}'";
