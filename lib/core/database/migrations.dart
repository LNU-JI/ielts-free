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
/// - `2`: v1 → v2 — profile columns for the display settings.
/// - `3`: v2 → v3 — V0.2 practice records for the listening, speaking and
///   writing modules, plus the sentence / phrase asset books they feed.
///
/// Every step is additive (`CREATE TABLE IF NOT EXISTS`, `ADD COLUMN`,
/// `CREATE INDEX IF NOT EXISTS`) and therefore safe to run on a database that
/// already contains user data.
final Map<int, List<String>> migrationSteps = <int, List<String>>{
  1: userSchemaStatements(),
  2: <String>[
    // Additive change: new profile columns with safe defaults.
    // `ADD COLUMN` with a NOT NULL DEFAULT is backward compatible and keeps
    // every existing row intact.
    "ALTER TABLE user_profile ADD COLUMN font_scale REAL NOT NULL DEFAULT 1.0",
    "ALTER TABLE user_profile ADD COLUMN theme_mode TEXT NOT NULL DEFAULT 'system'",
    // Additive index; speeds up per-skill correctness lookups.
    'CREATE INDEX IF NOT EXISTS idx_ua_user_correct ON user_answers(user_id, is_correct)',
  ],
  3: <String>[
    // --- Listening: the error log produced by the intensive-listening loop ---
    // The five error types come from the distilled IELTS method: a word you
    // never knew, a sound you mis-heard (linking / weak forms / elision), a
    // spelling slip, a structure you could not parse, or a paraphrase you did
    // not spot. Recording the CAUSE is what makes the next round different.
    '''
CREATE TABLE IF NOT EXISTS listening_error_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  section_id INTEGER NOT NULL,
  question_id INTEGER,
  cue_id INTEGER,
  error_type TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
)''',
    'CREATE INDEX IF NOT EXISTS idx_lel_user ON listening_error_log(user_id, created_at)',
    'CREATE INDEX IF NOT EXISTS idx_lel_type ON listening_error_log(user_id, error_type)',
    'CREATE INDEX IF NOT EXISTS idx_lel_section ON listening_error_log(user_id, section_id)',

    // --- Sentence book: hard-to-hear sentences kept for repeat practice ---
    // Shared by listening and reading; `source_type` says which.
    '''
CREATE TABLE IF NOT EXISTS sentence_book (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  source_type TEXT NOT NULL,
  source_id INTEGER NOT NULL,
  section_id INTEGER,
  text TEXT NOT NULL,
  translation TEXT,
  note TEXT,
  review_count INTEGER NOT NULL DEFAULT 0,
  mastered INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
)''',
    'CREATE INDEX IF NOT EXISTS idx_sb_user ON sentence_book(user_id, created_at)',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_sb_source ON sentence_book(user_id, source_type, source_id)',

    // --- Speaking: one row per recorded attempt ---
    '''
CREATE TABLE IF NOT EXISTS speaking_attempts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  question_id INTEGER NOT NULL,
  topic_id INTEGER NOT NULL,
  part INTEGER NOT NULL,
  duration_sec INTEGER NOT NULL DEFAULT 0,
  audio_path TEXT,
  self_rating TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
)''',
    'CREATE INDEX IF NOT EXISTS idx_sa_user ON speaking_attempts(user_id, created_at)',
    'CREATE INDEX IF NOT EXISTS idx_sa_question ON speaking_attempts(user_id, question_id)',

    // --- Writing: one row per timed attempt ---
    '''
CREATE TABLE IF NOT EXISTS writing_attempts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  task_id INTEGER NOT NULL,
  task_number INTEGER NOT NULL,
  content TEXT NOT NULL,
  word_count INTEGER NOT NULL DEFAULT 0,
  duration_sec INTEGER NOT NULL DEFAULT 0,
  self_rating TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
)''',
    'CREATE INDEX IF NOT EXISTS idx_wa_user ON writing_attempts(user_id, created_at)',
    'CREATE INDEX IF NOT EXISTS idx_wa_task ON writing_attempts(user_id, task_id)',

    // --- Phrase book: sentence patterns collected while writing ---
    '''
CREATE TABLE IF NOT EXISTS phrase_book (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  phrase_id INTEGER,
  phrase TEXT NOT NULL,
  meaning_cn TEXT,
  category TEXT,
  source TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
)''',
    'CREATE INDEX IF NOT EXISTS idx_pb_user ON phrase_book(user_id, created_at)',
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
