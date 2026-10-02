/// DAO for `app_settings`.
library;

import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/storage/dao/base_dao.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// Reads and writes key/value settings.
class SettingsDao extends BaseDao {
  SettingsDao(super.db);

  static const String _table = 'app_settings';

  /// Reads one setting value, or `null`.
  Future<String?> get(String userId, String key) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      columns: <String>['value'],
      where: 'user_id = ? AND key = ?',
      whereArgs: <Object?>[userId, key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String?;
  }

  /// All settings for [userId] as a `key → value` map.
  Future<Map<String, String>> all(String userId) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      columns: <String>['key', 'value'],
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
    );
    final Map<String, String> result = <String, String>{};
    for (final Map<String, Object?> row in rows) {
      final String? key = row['key'] as String?;
      if (key != null) {
        result[key] = row['value'] as String? ?? '';
      }
    }
    return result;
  }

  /// Writes one setting value (insert or replace).
  Future<void> set(String userId, String key, String? value) async {
    await db.insert(
      _table,
      <String, Object?>{
        'user_id': userId,
        'key': key,
        'value': value,
        'updated_at': AppDateUtils.nowUtcIso(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Reads a boolean setting.
  Future<bool> getBool(String userId, String key, {bool fallback = false}) async {
    final String? raw = await get(userId, key);
    if (raw == null) {
      return fallback;
    }
    final String value = raw.toLowerCase();
    return value == '1' || value == 'true';
  }

  /// Writes a boolean setting.
  Future<void> setBool(String userId, String key, bool value) =>
      set(userId, key, value ? '1' : '0');

  /// Removes a setting.
  Future<void> remove(String userId, String key) async {
    await db.delete(
      _table,
      where: 'user_id = ? AND key = ?',
      whereArgs: <Object?>[userId, key],
    );
  }
}
