/// Vocabulary repository — the only data interface the domain layer may use for
/// vocabulary content.
///
/// The interface is intentionally framework-agnostic so the SQLite
/// implementation can later be swapped (e.g. for Drift) without touching the
/// domain or application layers.
library;

import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/vocabulary.dart';
import 'package:ielts_free/core/models/vocabulary_topic.dart';
import 'package:ielts_free/core/storage/dao/content/vocabulary_dao.dart';
import 'package:ielts_free/core/storage/paging.dart';

/// Read access to vocabulary content.
abstract interface class VocabularyRepository {
  /// A page of vocabulary, optionally filtered.
  Future<PagedList<Vocabulary>> list({
    int page = 1,
    int pageSize = 20,
    String? topic,
    int? difficulty,
    String? query,
  });

  /// The vocabulary item with [id], or `null`.
  Future<Vocabulary?> byId(int id);

  /// The vocabulary item whose head word is [word], or `null`.
  Future<Vocabulary?> byWord(String word);

  /// Topics attached to one vocabulary item.
  Future<List<VocabularyTopic>> topicsFor(int vocabularyId);

  /// All distinct topics (for filter chips).
  Future<List<String>> topics();

  /// Total vocabulary count (respecting an optional topic filter).
  Future<int> count({String? topic});
}

/// SQLite-backed [VocabularyRepository].
class SqliteVocabularyRepository implements VocabularyRepository {
  SqliteVocabularyRepository(this._dao);

  final VocabularyDao _dao;

  @override
  Future<PagedList<Vocabulary>> list({
    int page = 1,
    int pageSize = 20,
    String? topic,
    int? difficulty,
    String? query,
  }) =>
      runDbGuarded('VOCAB_LIST', () async {
        final int safePage = page < 1 ? 1 : page;
        final int offset = (safePage - 1) * pageSize;
        final List<Vocabulary> items = await _dao.page(
          limit: pageSize,
          offset: offset,
          topic: topic,
          difficulty: difficulty,
          query: query,
        );
        final int total = await _dao.count(topic: topic);
        return PagedList<Vocabulary>(
          items: items,
          total: total,
          limit: pageSize,
          offset: offset,
        );
      });

  @override
  Future<Vocabulary?> byId(int id) =>
      runDbGuarded('VOCAB_BY_ID', () => _dao.byId(id));

  @override
  Future<Vocabulary?> byWord(String word) =>
      runDbGuarded('VOCAB_BY_WORD', () => _dao.byWord(word));

  @override
  Future<List<VocabularyTopic>> topicsFor(int vocabularyId) =>
      runDbGuarded('VOCAB_TOPICS', () => _dao.topicsFor(vocabularyId));

  @override
  Future<List<String>> topics() =>
      runDbGuarded('VOCAB_TOPIC_LIST', _dao.distinctTopics);

  @override
  Future<int> count({String? topic}) =>
      runDbGuarded('VOCAB_COUNT', () => _dao.count(topic: topic));
}
