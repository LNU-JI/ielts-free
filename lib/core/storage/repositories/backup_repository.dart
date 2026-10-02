/// Backup repository — Export / Import / Delete-My-Data (docs/BRIEF.md §43/§44/§87).
///
/// Export produces a single, self-describing JSON file
/// (`IELTS-Free-Backup.json`). Import restores it. Everything stays on device.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/database/migrations.dart';
import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// Read/write access to backup / restore / data deletion.
abstract interface class BackupRepository {
  /// Writes a JSON backup of [userId]'s data and returns the file path.
  Future<String> exportToJson(String userId);

  /// Restores data from a previously exported JSON string.
  Future<void> importFromJson(String json);

  /// Deletes all local data for [userId] (irreversible).
  Future<void> deleteAllUserData(String userId);

  /// Creates a raw SQLite copy of the user database and returns its path.
  Future<String> createDatabaseBackup();
}

/// SQLite-backed [BackupRepository].
class SqliteBackupRepository implements BackupRepository {
  SqliteBackupRepository(this._db, {required this.databasePath});

  final Database _db;
  final String databasePath;

  /// Tables keyed by the column that scopes them to a user (`id` or `user_id`).
  static const Map<String, String> _userScopedTables = <String, String>{
    'users': 'id',
    'user_profile': 'user_id',
    'study_goal': 'user_id',
    'study_plan': 'user_id',
    'daily_tasks': 'user_id',
    'vocabulary_reviews': 'user_id',
    'skill_scores': 'user_id',
    'user_answers': 'user_id',
    'mistakes': 'user_id',
    'learning_sessions': 'user_id',
    'learning_statistics': 'user_id',
    'favorites': 'user_id',
    'notes': 'user_id',
    'app_settings': 'user_id',
  };

  @override
  Future<String> exportToJson(String userId) =>
      runDbGuarded('BACKUP_EXPORT', () async {
        final Map<String, Object?> tables = <String, Object?>{};
        for (final MapEntry<String, String> entry in _userScopedTables.entries) {
          final List<Map<String, Object?>> rows = await _db.query(
            entry.key,
            where: '${entry.value} = ?',
            whereArgs: <Object?>[userId],
          );
          tables[entry.key] = rows;
        }

        final Map<String, Object?> payload = <String, Object?>{
          'app': AppConstants.appName,
          'format': 'ielts-free-backup',
          'version': AppConstants.appVersion,
          'dbVersion': kUserDbVersion,
          'exportedAt': AppDateUtils.nowUtcIso(),
          'userId': userId,
          'tables': tables,
        };

        final Directory documents = await getApplicationDocumentsDirectory();
        final File file =
            File(p.join(documents.path, AppConstants.backupFileName));
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(payload),
          flush: true,
        );
        return file.path;
      });

  @override
  Future<void> importFromJson(String json) =>
      runDbGuarded('BACKUP_IMPORT', () async {
        final Object? decoded = jsonDecode(json);
        if (decoded is! Map<String, Object?>) {
          throw const ValidationException('BACKUP_FORMAT', '备份文件格式不正确。');
        }
        final Object? tablesRaw = decoded['tables'];
        if (tablesRaw is! Map<String, Object?>) {
          throw const ValidationException('BACKUP_FORMAT', '备份文件缺少数据表。');
        }

        await _db.transaction<void>((Transaction txn) async {
          // Delete in FK-safe order (children first).
          for (final String table in _userScopedTables.keys.toList().reversed) {
            await txn.delete(table);
          }
          // Insert parents first.
          for (final String table in _userScopedTables.keys) {
            final Object? rowsRaw = tablesRaw[table];
            if (rowsRaw is! List<Object?>) {
              continue;
            }
            for (final Object? row in rowsRaw) {
              if (row is Map<String, Object?>) {
                await txn.insert(
                  table,
                  row,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            }
          }
        });
      });

  @override
  Future<void> deleteAllUserData(String userId) =>
      runDbGuarded('BACKUP_DELETE', () async {
        await _db.transaction<void>((Transaction txn) async {
          for (final String table in _userScopedTables.keys.toList().reversed) {
            final String column = _userScopedTables[table]!;
            await txn.delete(
              table,
              where: '$column = ?',
              whereArgs: <Object?>[userId],
            );
          }
        });
      });

  @override
  Future<String> createDatabaseBackup() => runDbGuarded(
        'BACKUP_VACUUM',
        () async {
          final Directory documents = await getApplicationDocumentsDirectory();
          final String dir = p.join(documents.path, AppConstants.backupsDirName);
          return vacuumBackup(sourcePath: databasePath, backupDirPath: dir);
        },
      );
}
