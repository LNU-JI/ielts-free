/// DAO for `study_goal`.
library;

import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/models/study_goal.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';

/// Reads and writes study goals.
class StudyGoalDao extends BaseDao {
  StudyGoalDao(super.db);

  static const String _table = 'study_goal';

  /// The active goal for [userId], or `null`.
  Future<StudyGoal?> activeForUser(String userId) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND is_active = ?',
      whereArgs: <Object?>[userId, 1],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return StudyGoal.fromMap(rows.first);
  }

  /// The goal with [id], or `null`.
  Future<StudyGoal?> byId(int id) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return StudyGoal.fromMap(rows.first);
  }

  /// Inserts [goal] and returns its new id.
  Future<int> insert(StudyGoal goal) async {
    final Map<String, Object?> map = goal.toMap()..remove('id');
    return db.insert(_table, map);
  }

  /// Updates an existing goal (requires a non-null [StudyGoal.id]).
  Future<void> update(StudyGoal goal) async {
    final int? id = goal.id;
    if (id == null) {
      throw ArgumentError('StudyGoal.id must be set before update().');
    }
    await db.update(
      _table,
      goal.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Marks every goal of [userId] inactive.
  Future<void> deactivateAll(String userId) async {
    await db.update(
      _table,
      <String, Object?>{'is_active': 0},
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
    );
  }

  /// Deactivates the current goal and inserts [goal] as the new active one.
  Future<int> saveActive(StudyGoal goal) async {
    return db.transaction<int>((Transaction txn) async {
      await txn.update(
        _table,
        <String, Object?>{'is_active': 0},
        where: 'user_id = ?',
        whereArgs: <Object?>[goal.userId],
      );
      final Map<String, Object?> map = goal.toMap()
        ..remove('id')
        ..['is_active'] = 1;
      return txn.insert(_table, map);
    });
  }
}
