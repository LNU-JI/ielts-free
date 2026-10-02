/// DAO for the `users` table.
///
/// Needed because `user_profile.user_id` carries a foreign key to `users(id)`
/// and `PRAGMA foreign_keys = ON` is enabled, so the `users` row must exist
/// before any dependent row is written.
library;

import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/models/user.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';

/// Reads and writes user rows.
class UserDao extends BaseDao {
  UserDao(super.db);

  static const String _table = 'users';

  /// The user with [id], or `null`.
  Future<User?> byId(String id) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return User.fromMap(rows.first);
  }

  /// Whether a user row exists.
  Future<bool> exists(String id) async {
    final int count =
        await countRows(_table, where: 'id = ?', whereArgs: <Object?>[id]);
    return count > 0;
  }

  /// Inserts [user], replacing any existing row with the same id.
  Future<void> upsert(User user) async {
    await db.insert(
      _table,
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Ensures a `users` row exists for [id] (insert-if-absent).
  Future<void> ensure(String id) async {
    final Map<String, Object?> row = User.localUser().toMap()..['id'] = id;
    await db.insert(
      _table,
      row,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
