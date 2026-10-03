/// DAO for `speaking_attempts`.
///
/// One row per recorded practice run; the aggregate queries feed the speaking
/// progress view without re-reading every attempt.
library;

import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/models/speaking_attempt.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';

/// Reads and writes speaking attempts.
class SpeakingAttemptDao extends BaseDao {
  SpeakingAttemptDao(super.db);

  static const String _table = 'speaking_attempts';

  /// Inserts one attempt and returns its new id.
  Future<int> insert(SpeakingAttempt attempt) async {
    final Map<String, Object?> map = attempt.toMap()..remove('id');
    return db.insert(_table, map);
  }

  /// The most recent attempts for one question, newest first.
  Future<List<SpeakingAttempt>> recentForQuestion(
    String userId,
    int questionId, {
    int limit = 5,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND question_id = ?',
      whereArgs: <Object?>[userId, questionId],
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(SpeakingAttempt.fromMap).toList(growable: false);
  }

  /// Total seconds spoken, optionally restricted to one IELTS [part].
  Future<int> totalDurationSec(String userId, {int? part}) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COALESCE(SUM(duration_sec), 0) AS s FROM $_table '
      'WHERE user_id = ?${part == null ? '' : ' AND part = ?'}',
      part == null ? <Object?>[userId] : <Object?>[userId, part],
    );
    if (rows.isEmpty) {
      return 0;
    }
    return asInt(rows.first['s']) ?? 0;
  }

  /// Number of attempts, optionally restricted to one IELTS [part].
  Future<int> countAttempts(String userId, {int? part}) async {
    if (part == null) {
      return countRows(_table, where: 'user_id = ?', whereArgs: <Object?>[userId]);
    }
    return countRows(
      _table,
      where: 'user_id = ? AND part = ?',
      whereArgs: <Object?>[userId, part],
    );
  }
}
