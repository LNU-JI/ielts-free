/// DAO for `writing_attempts`.
///
/// One row per timed writing attempt; the aggregate queries feed the writing
/// progress view without re-reading every essay.
library;

import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/models/writing_attempt.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';

/// Reads and writes writing attempts.
class WritingAttemptDao extends BaseDao {
  WritingAttemptDao(super.db);

  static const String _table = 'writing_attempts';

  /// Inserts one attempt and returns its new id.
  Future<int> insert(WritingAttempt attempt) async {
    final Map<String, Object?> map = attempt.toMap()..remove('id');
    return db.insert(_table, map);
  }

  /// The most recent attempts for one task, newest first.
  Future<List<WritingAttempt>> recentForTask(
    String userId,
    int taskId, {
    int limit = 5,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND task_id = ?',
      whereArgs: <Object?>[userId, taskId],
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(WritingAttempt.fromMap).toList(growable: false);
  }

  /// The most recent attempt for one task, or `null`.
  Future<WritingAttempt?> latestForTask(String userId, int taskId) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND task_id = ?',
      whereArgs: <Object?>[userId, taskId],
      orderBy: 'created_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return WritingAttempt.fromMap(rows.first);
  }

  /// Total words written, optionally restricted to one task number (1 or 2).
  Future<int> totalWordCount(String userId, {int? taskNumber}) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COALESCE(SUM(word_count), 0) AS s FROM $_table '
      'WHERE user_id = ?${taskNumber == null ? '' : ' AND task_number = ?'}',
      taskNumber == null ? <Object?>[userId] : <Object?>[userId, taskNumber],
    );
    if (rows.isEmpty) {
      return 0;
    }
    return asInt(rows.first['s']) ?? 0;
  }

  /// Number of attempts, optionally restricted to one task number.
  Future<int> countAttempts(String userId, {int? taskNumber}) async {
    if (taskNumber == null) {
      return countRows(_table, where: 'user_id = ?', whereArgs: <Object?>[userId]);
    }
    return countRows(
      _table,
      where: 'user_id = ? AND task_number = ?',
      whereArgs: <Object?>[userId, taskNumber],
    );
  }
}
