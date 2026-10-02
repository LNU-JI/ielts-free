/// Read-only DAO for the `vocabulary` / `vocabulary_topics` tables.
///
/// **Content DAOs are SELECT-only.** No method here ever writes, updates or
/// deletes (docs/ARCHITECTURE-v0.1.md §4.1). All list queries are paginated.
library;

import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/models/vocabulary.dart';
import 'package:ielts_free/core/models/vocabulary_topic.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';

/// Queries vocabulary content.
class VocabularyDao extends BaseDao {
  VocabularyDao(super.db);

  static const String _table = 'vocabulary';

  /// Returns one page of vocabulary, optionally filtered by [topic],
  /// [difficulty] and a free-text [query] against the word.
  Future<List<Vocabulary>> page({
    int limit = 20,
    int offset = 0,
    String? topic,
    int? difficulty,
    String? query,
  }) async {
    final String? like =
        (query != null && query.trim().isNotEmpty) ? '%${query.trim()}%' : null;

    if (topic != null && topic.isNotEmpty) {
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT v.* FROM $_table v '
        'JOIN vocabulary_topics vt ON vt.vocabulary_id = v.id '
        'WHERE vt.topic = ? '
        '${difficulty != null ? 'AND v.difficulty = ? ' : ''}'
        '${like != null ? 'AND v.word LIKE ? ' : ''}'
        'ORDER BY v.word ASC LIMIT ? OFFSET ?',
        <Object?>[
          topic,
          if (difficulty != null) difficulty,
          if (like != null) like,
          limit,
          offset,
        ],
      );
      return rows.map(Vocabulary.fromMap).toList(growable: false);
    }

    final List<String> clauses = <String>[];
    final List<Object?> args = <Object?>[];
    if (difficulty != null) {
      clauses.add('difficulty = ?');
      args.add(difficulty);
    }
    if (like != null) {
      clauses.add('word LIKE ?');
      args.add(like);
    }
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: clauses.isEmpty ? null : args,
      orderBy: 'word ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Vocabulary.fromMap).toList(growable: false);
  }

  /// Total number of vocabulary rows (respecting an optional topic filter).
  Future<int> count({String? topic}) async {
    if (topic != null && topic.isNotEmpty) {
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $_table v '
        'JOIN vocabulary_topics vt ON vt.vocabulary_id = v.id '
        'WHERE vt.topic = ?',
        <Object?>[topic],
      );
      return Sqflite.firstIntValue(rows) ?? 0;
    }
    return countRows(_table);
  }

  /// Returns the vocabulary row with [id], or `null`.
  Future<Vocabulary?> byId(int id) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Vocabulary.fromMap(rows.first);
  }

  /// Returns the vocabulary row whose head word is [word], or `null`.
  Future<Vocabulary?> byWord(String word) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'word = ?',
      whereArgs: <Object?>[word],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Vocabulary.fromMap(rows.first);
  }

  /// Returns the vocabulary rows for a list of ids (used to hydrate a page).
  Future<List<Vocabulary>> byIds(List<int> ids) async {
    if (ids.isEmpty) {
      return const <Vocabulary>[];
    }
    final String placeholders = List<String>.filled(ids.length, '?').join(',');
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'id IN ($placeholders)',
      whereArgs: ids.cast<Object?>(),
      orderBy: 'word ASC',
    );
    return rows.map(Vocabulary.fromMap).toList(growable: false);
  }

  /// Topics attached to one vocabulary item.
  Future<List<VocabularyTopic>> topicsFor(int vocabularyId) async {
    final List<Map<String, Object?>> rows = await db.query(
      'vocabulary_topics',
      where: 'vocabulary_id = ?',
      whereArgs: <Object?>[vocabularyId],
      orderBy: 'topic ASC',
    );
    return rows.map(VocabularyTopic.fromMap).toList(growable: false);
  }

  /// Distinct topic names (for filter chips).
  Future<List<String>> distinctTopics() async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT DISTINCT topic FROM vocabulary_topics ORDER BY topic ASC',
    );
    return rows
        .map((Map<String, Object?> r) => r['topic'] as String? ?? '')
        .where((String t) => t.isNotEmpty)
        .toList(growable: false);
  }

  /// Vocabulary ids carrying [topic] (for building review queues).
  Future<List<int>> idsByTopic(String topic, {int limit = 50}) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT vocabulary_id FROM vocabulary_topics '
      'WHERE topic = ? ORDER BY vocabulary_id ASC LIMIT ?',
      <Object?>[topic, limit],
    );
    return rows
        .map((Map<String, Object?> r) => r['vocabulary_id'] as int? ?? 0)
        .where((int id) => id > 0)
        .toList(growable: false);
  }

  /// Number of words per difficulty (content statistics).
  Future<Map<int, int>> countByDifficulty() async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT difficulty, COUNT(*) AS c FROM $_table GROUP BY difficulty',
    );
    return <int, int>{
      for (final Map<String, Object?> row in rows)
        (row['difficulty'] as int? ?? 0): (row['c'] as int? ?? 0),
    };
  }
}
