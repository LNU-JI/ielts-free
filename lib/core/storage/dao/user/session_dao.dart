/// DAO for `learning_sessions`.
library;

import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/models/learning_session.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';

/// Reads and writes learning sessions (crash-recovery checkpoints).
class SessionDao extends BaseDao {
  SessionDao(super.db);

  static const String _table = 'learning_sessions';

  /// Inserts a new session.
  Future<void> insert(LearningSession session) async {
    await db.insert(
      _table,
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates an existing session (requires a non-empty [LearningSession.id]).
  Future<void> update(LearningSession session) async {
    await db.update(
      _table,
      session.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[session.id],
    );
  }

  /// The session with [id], or `null`.
  Future<LearningSession?> byId(String id) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return LearningSession.fromMap(rows.first);
  }

  /// The most recent still-active session for [userId], or `null`.
  Future<LearningSession?> activeForUser(String userId) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND status = ?',
      whereArgs: <Object?>[userId, 'ACTIVE'],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return LearningSession.fromMap(rows.first);
  }

  /// The most recent sessions for [userId].
  Future<List<LearningSession>> recent(String userId, {int limit = 20}) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map(LearningSession.fromMap).toList(growable: false);
  }

  /// Deletes one session.
  Future<void> delete(String id) async {
    await db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id]);
  }
}
