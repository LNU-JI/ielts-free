/// DAO for `mistakes`.
library;

import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/models/enums/error_type.dart';
import 'package:ielts_free/core/models/enums/mistake_status.dart';
import 'package:ielts_free/core/models/enums/ref_type.dart';
import 'package:ielts_free/core/models/mistake.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// Reads and writes the mistake queue.
class MistakeDao extends BaseDao {
  MistakeDao(super.db);

  static const String _table = 'mistakes';

  /// The mistake for a given `(ref_type, ref_id)`, or `null`.
  Future<Mistake?> byRef(String userId, RefType refType, int refId) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND ref_type = ? AND ref_id = ?',
      whereArgs: <Object?>[userId, refType.wire, refId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Mistake.fromMap(rows.first);
  }

  /// The mistake with [id], or `null`.
  Future<Mistake?> byId(int id) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Mistake.fromMap(rows.first);
  }

  /// Inserts [mistake] and returns its new id.
  Future<int> insert(Mistake mistake) async {
    final Map<String, Object?> map = mistake.toMap()..remove('id');
    return db.insert(_table, map);
  }

  /// Updates an existing mistake (requires a non-null [Mistake.id]).
  Future<void> update(Mistake mistake) async {
    final int? id = mistake.id;
    if (id == null) {
      throw ArgumentError('Mistake.id must be set before update().');
    }
    await db.update(
      _table,
      mistake.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Records a wrong answer: inserts a new mistake, or bumps the existing one.
  ///
  /// Runs in a transaction so the read-then-write is atomic. Returns the row id.
  Future<int> recordWrong(Mistake mistake) async {
    final RefType? refType = mistake.refType;
    final int? refId = mistake.refId;
    if (refType == null || refId == null) {
      throw ArgumentError('Mistake.refType and refId are required.');
    }
    final String userId = mistake.userId ?? '';

    return db.transaction<int>((Transaction txn) async {
      final List<Map<String, Object?>> existing = await txn.query(
        _table,
        columns: <String>['id', 'wrong_count'],
        where: 'user_id = ? AND ref_type = ? AND ref_id = ?',
        whereArgs: <Object?>[userId, refType.wire, refId],
        limit: 1,
      );

      final String stamp = AppDateUtils.toUtcIso(
        mistake.lastWrongAt ?? DateTime.now().toUtc(),
      );

      if (existing.isEmpty) {
        final Map<String, Object?> map = mistake.toMap()
          ..remove('id')
          ..['wrong_count'] = mistake.wrongCount < 1 ? 1 : mistake.wrongCount
          ..['last_wrong_at'] = stamp;
        return txn.insert(_table, map);
      }

      final int id = existing.first['id'] as int? ?? 0;
      final int previous = existing.first['wrong_count'] as int? ?? 0;
      await txn.update(
        _table,
        <String, Object?>{
          'user_answer': mistake.userAnswer,
          'correct_answer': mistake.correctAnswer,
          'error_type': mistake.errorType?.wire,
          'difficulty': mistake.difficulty,
          'question_type': mistake.questionType?.wire,
          'skill': mistake.skill?.wire,
          'wrong_count': previous + 1,
          'last_wrong_at': stamp,
          'updated_at': stamp,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      return id;
    });
  }

  /// One page of mistakes, newest-wrong first.
  Future<List<Mistake>> page(
    String userId, {
    int limit = 20,
    int offset = 0,
    RefType? refType,
    ErrorType? errorType,
    bool onlyActive = true,
  }) async {
    final List<String> clauses = <String>['user_id = ?'];
    final List<Object?> args = <Object?>[userId];
    if (refType != null) {
      clauses.add('ref_type = ?');
      args.add(refType.wire);
    }
    if (errorType != null) {
      clauses.add('error_type = ?');
      args.add(errorType.wire);
    }
    if (onlyActive) {
      clauses.add('mastery < ?');
      args.add(MistakeStatus.masteryThreshold);
    }
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'last_wrong_at DESC, wrong_count DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Mistake.fromMap).toList(growable: false);
  }

  /// Number of mistakes matching the filter.
  Future<int> count(
    String userId, {
    RefType? refType,
    ErrorType? errorType,
    bool onlyActive = true,
  }) async {
    final List<String> clauses = <String>['user_id = ?'];
    final List<Object?> args = <Object?>[userId];
    if (refType != null) {
      clauses.add('ref_type = ?');
      args.add(refType.wire);
    }
    if (errorType != null) {
      clauses.add('error_type = ?');
      args.add(errorType.wire);
    }
    if (onlyActive) {
      clauses.add('mastery < ?');
      args.add(MistakeStatus.masteryThreshold);
    }
    return countRows(_table, where: clauses.join(' AND '), whereArgs: args);
  }

  /// Number of active (not yet mastered) mistakes.
  Future<int> countActive(String userId) => countRows(
        _table,
        where: 'user_id = ? AND mastery < ?',
        whereArgs: <Object?>[userId, MistakeStatus.masteryThreshold],
      );

  /// Active mistakes ordered by review priority (wrong count desc).
  Future<List<Mistake>> forReview(String userId, {int limit = 10}) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND mastery < ?',
      whereArgs: <Object?>[userId, MistakeStatus.masteryThreshold],
      orderBy: 'wrong_count DESC, last_wrong_at ASC',
      limit: limit,
    );
    return rows.map(Mistake.fromMap).toList(growable: false);
  }

  /// Updates the mastery value of one mistake.
  Future<void> updateMastery(int id, double mastery) async {
    await db.update(
      _table,
      <String, Object?>{
        'mastery': mastery.clamp(0, 1).toDouble(),
        'updated_at': AppDateUtils.nowUtcIso(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Counts active mistakes grouped by error type.
  Future<Map<String, int>> countByErrorType(String userId) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT error_type, COUNT(*) AS c FROM $_table '
      'WHERE user_id = ? AND mastery < ? GROUP BY error_type',
      <Object?>[userId, MistakeStatus.masteryThreshold],
    );
    return <String, int>{
      for (final Map<String, Object?> row in rows)
        (row['error_type'] as String? ?? ''): (row['c'] as int? ?? 0),
    };
  }

  /// Deletes every mistake of [userId] (used by "reset learning data").
  Future<void> deleteForUser(String userId) async {
    await db.delete(_table, where: 'user_id = ?', whereArgs: <Object?>[userId]);
  }
}
