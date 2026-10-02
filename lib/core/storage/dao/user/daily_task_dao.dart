/// DAO for `daily_tasks`.
library;

import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/models/daily_task.dart';
import 'package:ielts_free/core/models/enums/task_status.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// Reads and writes daily tasks.
class DailyTaskDao extends BaseDao {
  DailyTaskDao(super.db);

  static const String _table = 'daily_tasks';

  /// All tasks for [userId] on [planDate], ordered by `sort_order`.
  Future<List<DailyTask>> forDate(String userId, String planDate) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND plan_date = ?',
      whereArgs: <Object?>[userId, planDate],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(DailyTask.fromMap).toList(growable: false);
  }

  /// The task with [id], or `null`.
  Future<DailyTask?> byId(int id) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return DailyTask.fromMap(rows.first);
  }

  /// Number of tasks for [userId] on [planDate].
  Future<int> countForDate(String userId, String planDate) => countRows(
        _table,
        where: 'user_id = ? AND plan_date = ?',
        whereArgs: <Object?>[userId, planDate],
      );

  /// Replaces all tasks for [userId] on [planDate] with [tasks] (transaction).
  Future<void> replaceForDate(
    String userId,
    String planDate,
    List<DailyTask> tasks,
  ) async {
    await db.transaction<void>((Transaction txn) async {
      await txn.delete(
        _table,
        where: 'user_id = ? AND plan_date = ?',
        whereArgs: <Object?>[userId, planDate],
      );
      for (final DailyTask task in tasks) {
        final Map<String, Object?> map = task.toMap()..remove('id');
        await txn.insert(_table, map);
      }
    });
  }

  /// Inserts many tasks in one transaction.
  Future<void> insertAll(List<DailyTask> tasks) async {
    if (tasks.isEmpty) {
      return;
    }
    await db.transaction<void>((Transaction txn) async {
      for (final DailyTask task in tasks) {
        final Map<String, Object?> map = task.toMap()..remove('id');
        await txn.insert(_table, map);
      }
    });
  }

  /// Updates the progress of one task.
  Future<void> updateProgress(
    int id, {
    required int completedCount,
    required TaskStatus status,
  }) async {
    await db.update(
      _table,
      <String, Object?>{
        'completed_count': completedCount,
        'status': status.wire,
        'updated_at': AppDateUtils.nowUtcIso(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Average completion ratio of [userId]'s tasks on [planDate], in `[0, 1]`.
  Future<double> completionRatio(String userId, String planDate) async {
    final List<DailyTask> tasks = await forDate(userId, planDate);
    if (tasks.isEmpty) {
      return 0;
    }
    double sum = 0;
    for (final DailyTask task in tasks) {
      sum += task.progress;
    }
    return sum / tasks.length;
  }

  /// Deletes all tasks for [userId] on [planDate].
  Future<void> clearForDate(String userId, String planDate) async {
    await db.delete(
      _table,
      where: 'user_id = ? AND plan_date = ?',
      whereArgs: <Object?>[userId, planDate],
    );
  }
}
