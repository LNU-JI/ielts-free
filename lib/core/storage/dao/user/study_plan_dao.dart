/// DAO for `study_plan`.
library;

import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/models/study_plan.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';

/// Reads and writes study-plan days.
class StudyPlanDao extends BaseDao {
  StudyPlanDao(super.db);

  static const String _table = 'study_plan';

  /// One page of plan days for [userId], ordered by date.
  Future<List<StudyPlan>> forUser(
    String userId, {
    int limit = 30,
    int offset = 0,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      orderBy: 'plan_date ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(StudyPlan.fromMap).toList(growable: false);
  }

  /// The plan day for [planDate] (`YYYY-MM-DD`), or `null`.
  Future<StudyPlan?> byDate(String userId, String planDate) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND plan_date = ?',
      whereArgs: <Object?>[userId, planDate],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return StudyPlan.fromMap(rows.first);
  }

  /// Number of plan days for [userId].
  Future<int> countForUser(String userId) =>
      countRows(_table, where: 'user_id = ?', whereArgs: <Object?>[userId]);

  /// Inserts many plan days in a single transaction.
  Future<void> insertAll(List<StudyPlan> plans) async {
    if (plans.isEmpty) {
      return;
    }
    await db.transaction<void>((Transaction txn) async {
      for (final StudyPlan plan in plans) {
        final Map<String, Object?> map = plan.toMap()..remove('id');
        await txn.insert(_table, map);
      }
    });
  }

  /// Inserts or replaces the plan day identified by `(user_id, plan_date)`.
  Future<void> upsert(StudyPlan plan) async {
    await db.insert(
      _table,
      plan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes every plan day for [userId] (used before regenerating a plan).
  Future<void> deleteForUser(String userId) async {
    await db.delete(_table, where: 'user_id = ?', whereArgs: <Object?>[userId]);
  }
}
