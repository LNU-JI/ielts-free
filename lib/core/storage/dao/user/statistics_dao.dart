/// DAO for `learning_statistics`.
library;

import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/models/learning_statistics.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';

/// Reads and writes per-day statistics and running totals.
class StatisticsDao extends BaseDao {
  StatisticsDao(super.db);

  static const String _table = 'learning_statistics';

  /// The statistics row for a specific day, or `null`.
  Future<LearningStatistics?> forDate(String userId, String statDate) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND stat_date = ?',
      whereArgs: <Object?>[userId, statDate],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return LearningStatistics.fromMap(rows.first);
  }

  /// The most recent statistics row for [userId], or `null`.
  Future<LearningStatistics?> latest(String userId) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      orderBy: 'stat_date DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return LearningStatistics.fromMap(rows.first);
  }

  /// Inserts or replaces the row for `(user, stat_date)`.
  Future<void> upsert(LearningStatistics stats) async {
    await db.insert(
      _table,
      stats.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Lifetime study minutes for [userId] (max across day rows).
  Future<int> totalStudyMinutes(String userId) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT MAX(total_study_minutes) AS m FROM $_table WHERE user_id = ?',
      <Object?>[userId],
    );
    if (rows.isEmpty) {
      return 0;
    }
    return rows.first['m'] as int? ?? 0;
  }

  /// Lifetime number of answers recorded in `user_answers` for [userId].
  ///
  /// The per-day `questions_answered` column only holds one day's count, so the
  /// cumulative "questions answered" figure has to be aggregated from the raw
  /// answer log instead.
  Future<int> totalAnswers(String userId) => countRows(
        'user_answers',
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
      );

  /// Lifetime number of correct answers in `user_answers` for [userId].
  Future<int> totalCorrectAnswers(String userId) => countRows(
        'user_answers',
        where: 'user_id = ? AND is_correct = ?',
        whereArgs: <Object?>[userId, 1],
      );

  /// Lifetime number of distinct LOCAL study days for [userId].
  ///
  /// `answered_at` is stored as a UTC ISO-8601 string; SQLite's `localtime`
  /// modifier maps it back to the device's calendar day so the count matches
  /// the local-day semantics of the streak and daily plan.
  Future<int> totalStudyDays(String userId) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "SELECT COUNT(DISTINCT date(answered_at, 'localtime')) AS d "
      'FROM user_answers WHERE user_id = ?',
      <Object?>[userId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// One page of daily statistics, newest first.
  Future<List<LearningStatistics>> page(
    String userId, {
    int limit = 30,
    int offset = 0,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      orderBy: 'stat_date DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(LearningStatistics.fromMap).toList(growable: false);
  }
}
