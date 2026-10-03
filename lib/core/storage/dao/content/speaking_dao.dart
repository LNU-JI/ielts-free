/// Read-only DAO for speaking content
/// (`speaking_topics` / `speaking_questions`).
///
/// **SELECT-only** (docs/ARCHITECTURE-v0.1.md §4.1). Lists are paginated and
/// the caller composes a full topic from [topicById] and [questionsForTopic].
library;

import 'package:ielts_free/core/models/speaking_question.dart';
import 'package:ielts_free/core/models/speaking_topic.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';

/// Queries speaking content.
class SpeakingDao extends BaseDao {
  SpeakingDao(super.db);

  /// One page of topics, optionally filtered by IELTS [part] (1–3).
  Future<List<SpeakingTopic>> page({
    int limit = 20,
    int offset = 0,
    int? part,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      'speaking_topics',
      where: part == null ? null : 'part = ?',
      whereArgs: part == null ? null : <Object?>[part],
      orderBy: 'id ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(SpeakingTopic.fromMap).toList(growable: false);
  }

  /// Total number of topics (respecting an optional [part] filter).
  Future<int> countTopics({int? part}) async {
    if (part != null) {
      return countRows(
        'speaking_topics',
        where: 'part = ?',
        whereArgs: <Object?>[part],
      );
    }
    return countRows('speaking_topics');
  }

  /// Returns the topic with [id], or `null`.
  Future<SpeakingTopic?> topicById(int id) async {
    final List<Map<String, Object?>> rows = await db.query(
      'speaking_topics',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return SpeakingTopic.fromMap(rows.first);
  }

  /// Questions of a topic, ordered by `order_index`.
  Future<List<SpeakingQuestion>> questionsForTopic(int topicId) async {
    final List<Map<String, Object?>> rows = await db.query(
      'speaking_questions',
      where: 'topic_id = ?',
      whereArgs: <Object?>[topicId],
      orderBy: 'order_index ASC',
    );
    return rows.map(SpeakingQuestion.fromMap).toList(growable: false);
  }

  /// A random topic, optionally restricted to [part]; `null` when none exist.
  Future<SpeakingTopic?> randomTopic({int? part}) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      part == null
          ? 'SELECT * FROM speaking_topics ORDER BY RANDOM() LIMIT 1'
          : 'SELECT * FROM speaking_topics WHERE part = ? '
              'ORDER BY RANDOM() LIMIT 1',
      part == null ? null : <Object?>[part],
    );
    if (rows.isEmpty) {
      return null;
    }
    return SpeakingTopic.fromMap(rows.first);
  }
}
