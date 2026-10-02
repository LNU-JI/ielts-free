/// DAO for `user_profile`.
library;

import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/models/user_profile.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// Reads and writes the single user-profile row.
class UserProfileDao extends BaseDao {
  UserProfileDao(super.db);

  static const String _table = 'user_profile';

  /// The profile for [userId], or `null`.
  Future<UserProfile?> get(String userId) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return UserProfile.fromMap(rows.first);
  }

  /// Whether a profile exists for [userId].
  Future<bool> exists(String userId) async {
    final int count =
        await countRows(_table, where: 'user_id = ?', whereArgs: <Object?>[userId]);
    return count > 0;
  }

  /// Inserts or replaces the profile row.
  Future<void> upsert(UserProfile profile) async {
    await db.insert(
      _table,
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates just the onboarding flag for [userId].
  Future<void> setOnboardingCompleted(String userId, bool completed) async {
    await db.update(
      _table,
      <String, Object?>{
        'onboarding_completed': completed ? 1 : 0,
        'updated_at': AppDateUtils.nowUtcIso(),
      },
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
    );
  }
}
