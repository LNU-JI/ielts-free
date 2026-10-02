/// Read-write user database.
///
/// Opens `<documents>/ielts_user_v1.db` with the schema version
/// [kUserDbVersion]. Responsibilities:
///
/// - enable foreign keys on every connection (`onConfigure`);
/// - create the schema on first run and run migrations on upgrade;
/// - **back up the file before an upgrade** so a failed migration can be rolled
///   back without data loss (docs/BRIEF.md §71–75, NFR-30).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' hide DatabaseException;

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/database/migrations.dart';
import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Manages the user database connection.
class AppDatabase {
  AppDatabase({
    this.fileName = AppConstants.userDbFileName,
    this.version = kUserDbVersion,
    this.backupsDirName = AppConstants.backupsDirName,
  });

  /// File name of the user database.
  final String fileName;

  /// Target schema version.
  final int version;

  /// Sub-directory (under the documents directory) holding pre-upgrade backups.
  final String backupsDirName;

  Database? _db;
  Future<Database>? _dbFuture;

  /// The open database (opens on first access).
  ///
  /// The in-flight [Future] is cached so concurrent callers — the bootstrap
  /// sequence and the settings controller both touch the user DB at startup —
  /// share a single connection instead of racing to open two.
  Future<Database> get database => _dbFuture ??= _openAndCache();

  Future<Database> _openAndCache() async {
    final Database db = await open();
    _db = db;
    return db;
  }

  /// Absolute path of the user database file.
  Future<String> databasePath() async {
    final Directory documents = await getApplicationDocumentsDirectory();
    return p.join(documents.path, fileName);
  }

  /// Absolute path of the backups directory.
  Future<String> backupsDirectoryPath() async {
    final Directory documents = await getApplicationDocumentsDirectory();
    return p.join(documents.path, backupsDirName);
  }

  /// Whether the user database file already exists on disk.
  Future<bool> exists() async => File(await databasePath()).exists();

  /// Opens the user database, creating / migrating the schema as needed.
  Future<Database> open() async {
    try {
      final String path = await databasePath();
      await _backupBeforeUpgrade(path);

      return await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: version,
          onConfigure: (Database db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: (Database db, int newVersion) =>
              runMigrations(db, from: 0, to: newVersion),
          onUpgrade: (Database db, int oldVersion, int newVersion) =>
              runMigrations(db, from: oldVersion, to: newVersion),
        ),
      );
    } on Object catch (error, stackTrace) {
      throw DatabaseException(
        'USER_DB_OPEN_FAILED',
        '本地数据访问失败，请重试。',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Closes the connection (safe to call multiple times).
  Future<void> close() async {
    final Database? db = _db;
    _db = null;
    _dbFuture = null;
    await db?.close();
  }

  /// Copies the existing file into `backups/` when an upgrade is about to run.
  Future<void> _backupBeforeUpgrade(String path) async {
    final File file = File(path);
    if (!await file.exists()) {
      return;
    }
    final int existingVersion = await _readUserVersion(path);
    if (existingVersion <= 0 || existingVersion >= version) {
      return;
    }

    final String backupsDir = await backupsDirectoryPath();
    try {
      final String backupPath = await vacuumBackup(
        sourcePath: path,
        backupDirPath: backupsDir,
      );
      appLogger.info(
        'Backed up user DB v$existingVersion → $backupPath before upgrade.',
      );
    } on Object catch (error, stackTrace) {
      // Fall back to a plain file copy; a backup failure must never block the
      // upgrade itself (the app still migrates additively).
      appLogger.warning('VACUUM INTO backup failed, copying file.', error,
          stackTrace);
      await fileCopyBackup(sourcePath: path, backupDirPath: backupsDir);
    }
  }

  /// Reads `PRAGMA user_version` without applying migrations.
  Future<int> _readUserVersion(String path) async {
    final Database probe = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    try {
      final List<Map<String, Object?>> rows =
          await probe.rawQuery('PRAGMA user_version');
      return Sqflite.firstIntValue(rows) ?? 0;
    } finally {
      await probe.close();
    }
  }
}
