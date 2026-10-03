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

  /// Delimiter used by [page] to collapse a word's topics into one column.
  /// Shared with `Vocabulary._decodeAggregatedTopics`.
  static const String _topicDelimiter = ',';

  /// Returns one page of vocabulary, optionally filtered by [topic],
  /// [difficulty] and a free-text [query] against the word **or** its Chinese
  /// meaning.
  ///
  /// Every returned word carries its own aggregated [Vocabulary.topics]: the
  /// `vocabulary_topics` rows are `LEFT JOIN`ed and collapsed with
  /// `GROUP_CONCAT`, so the topics come back in **one** query (no N+1). The
  /// concatenation order follows the `idx_vt_vocab` index scan (i.e. authoring
  /// order in practice); callers must not rely on a guaranteed order.
  Future<List<Vocabulary>> page({
    int limit = 20,
    int offset = 0,
    String? topic,
    int? difficulty,
    String? query,
  }) async {
    final String? like =
        (query != null && query.trim().isNotEmpty) ? '%${query.trim()}%' : null;

    final List<String> clauses = <String>[];
    final List<Object?> args = <Object?>[];

    if (topic != null && topic.isNotEmpty) {
      // EXISTS keeps the row set duplicate-free even if a word carries the same
      // topic twice, where a plain JOIN would emit the word once per match.
      clauses.add('EXISTS (SELECT 1 FROM vocabulary_topics ft '
          'WHERE ft.vocabulary_id = v.id AND ft.topic = ?)');
      args.add(topic);
    }
    if (difficulty != null) {
      clauses.add('v.difficulty = ?');
      args.add(difficulty);
    }
    if (like != null) {
      // Match the head word OR the Chinese meaning, so users can search in
      // either language. The same pattern is bound twice.
      clauses.add('(v.word LIKE ? OR v.meaning_cn LIKE ?)');
      args.add(like);
      args.add(like);
    }

    final String where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT v.*, GROUP_CONCAT(vt.topic, \'$_topicDelimiter\') AS topics '
      'FROM $_table v '
      'LEFT JOIN vocabulary_topics vt ON vt.vocabulary_id = v.id '
      '$where '
      'GROUP BY v.id '
      'ORDER BY v.word ASC LIMIT ? OFFSET ?',
      <Object?>[...args, limit, offset],
    );
    return rows.map(Vocabulary.fromMap).toList(growable: false);
  }

  /// Total number of vocabulary rows (respecting an optional topic filter).
  Future<int> count({String? topic}) async {
    if (topic != null && topic.isNotEmpty) {
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $_table v '
        'WHERE EXISTS (SELECT 1 FROM vocabulary_topics vt '
        'WHERE vt.vocabulary_id = v.id AND vt.topic = ?)',
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
