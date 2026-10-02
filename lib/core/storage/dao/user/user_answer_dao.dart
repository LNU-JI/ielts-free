/// DAO for `user_answers`.
library;


import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/user_answer.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// Reads and writes the answer log.
class UserAnswerDao extends BaseDao {
  UserAnswerDao(super.db);

  static const String _table = 'user_answers';

  /// Inserts one answer and returns its new id.
  Future<int> insert(UserAnswer answer) async {
    final Map<String, Object?> map = answer.toMap()..remove('id');
    return db.insert(_table, map);
  }

  /// One page of answers for [userId], newest first.
  Future<List<UserAnswer>> page(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      orderBy: 'answered_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(UserAnswer.fromMap).toList(growable: false);
  }

  /// The most recent [limit] answers, optionally filtered by [skill].
  Future<List<UserAnswer>> recent(
    String userId, {
    int limit = 20,
    SkillType? skill,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: skill == null ? 'user_id = ?' : 'user_id = ? AND skill = ?',
      whereArgs:
          skill == null ? <Object?>[userId] : <Object?>[userId, skill.wire],
      orderBy: 'answered_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(UserAnswer.fromMap).toList(growable: false);
  }

  /// Answers recorded since [since] (UTC), newest first.
  Future<List<UserAnswer>> since(
    String userId,
    DateTime since, {
    int limit = 100,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND answered_at >= ?',
      whereArgs: <Object?>[userId, AppDateUtils.toUtcIso(since)],
      orderBy: 'answered_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(UserAnswer.fromMap).toList(growable: false);
  }

  /// Number of answers recorded since [since] (UTC).
  Future<int> countSince(String userId, DateTime since) => countRows(
        _table,
        where: 'user_id = ? AND answered_at >= ?',
        whereArgs: <Object?>[userId, AppDateUtils.toUtcIso(since)],
      );

  /// Number of correct answers since [since] (UTC).
  Future<int> countCorrectSince(String userId, DateTime since) => countRows(
        _table,
        where: 'user_id = ? AND answered_at >= ? AND is_correct = ?',
        whereArgs: <Object?>[userId, AppDateUtils.toUtcIso(since), 1],
      );
}
