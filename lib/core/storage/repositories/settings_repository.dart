/// Settings repository.
library;

import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/storage/dao/user/settings_dao.dart';

/// Read/write access to key/value settings.
abstract interface class SettingsRepository {
  /// Reads one setting value, or `null`.
  Future<String?> get(String userId, String key);

  /// Reads all settings for [userId].
  Future<Map<String, String>> all(String userId);

  /// Writes one setting value.
  Future<void> set(String userId, String key, String? value);

  /// Reads a boolean setting.
  Future<bool> getBool(String userId, String key, {bool fallback = false});

  /// Writes a boolean setting.
  Future<void> setBool(String userId, String key, bool value);

  /// Removes a setting.
  Future<void> remove(String userId, String key);
}

/// SQLite-backed [SettingsRepository].
class SqliteSettingsRepository implements SettingsRepository {
  SqliteSettingsRepository(this._dao);

  final SettingsDao _dao;

  @override
  Future<String?> get(String userId, String key) =>
      runDbGuarded('SETTINGS_GET', () => _dao.get(userId, key));

  @override
  Future<Map<String, String>> all(String userId) =>
      runDbGuarded('SETTINGS_ALL', () => _dao.all(userId));

  @override
  Future<void> set(String userId, String key, String? value) =>
      runDbGuarded('SETTINGS_SET', () => _dao.set(userId, key, value));

  @override
  Future<bool> getBool(String userId, String key, {bool fallback = false}) =>
      runDbGuarded('SETTINGS_GET_BOOL', () => _dao.getBool(userId, key, fallback: fallback));

  @override
  Future<void> setBool(String userId, String key, bool value) =>
      runDbGuarded('SETTINGS_SET_BOOL', () => _dao.setBool(userId, key, value));

  @override
  Future<void> remove(String userId, String key) =>
      runDbGuarded('SETTINGS_REMOVE', () => _dao.remove(userId, key));
}
