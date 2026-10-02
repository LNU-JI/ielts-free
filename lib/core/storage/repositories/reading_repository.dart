/// Reading repository — the only data interface the domain layer may use for
/// reading content.
library;

import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/reading_passage.dart';
import 'package:ielts_free/core/models/reading_question.dart';
import 'package:ielts_free/core/storage/dao/content/reading_dao.dart';
import 'package:ielts_free/core/storage/paging.dart';

/// Read access to reading content.
abstract interface class ReadingRepository {
  /// A page of passages, optionally filtered.
  Future<PagedList<ReadingPassage>> list({
    int page = 1,
    int pageSize = 20,
    int? difficulty,
    String? topic,
  });

  /// The passage with [id], or `null`.
  Future<ReadingPassage?> passageById(int id);

  /// The questions of a passage with their options attached.
  Future<List<ReadingQuestion>> questionsWithOptions(int passageId);

  /// The question with [id], or `null`.
  Future<ReadingQuestion?> questionById(int id);

  /// All distinct passage topics.
  Future<List<String>> topics();

  /// Total number of passages.
  Future<int> countPassages();

  /// Total number of questions.
  Future<int> countQuestions();
}

/// SQLite-backed [ReadingRepository].
class SqliteReadingRepository implements ReadingRepository {
  SqliteReadingRepository(this._dao);

  final ReadingDao _dao;

  @override
  Future<PagedList<ReadingPassage>> list({
    int page = 1,
    int pageSize = 20,
    int? difficulty,
    String? topic,
  }) =>
      runDbGuarded('READING_LIST', () async {
        final int safePage = page < 1 ? 1 : page;
        final int offset = (safePage - 1) * pageSize;
        final List<ReadingPassage> items = await _dao.page(
          limit: pageSize,
          offset: offset,
          difficulty: difficulty,
          topic: topic,
        );
        final int total = await _dao.countPassages(topic: topic);
        return PagedList<ReadingPassage>(
          items: items,
          total: total,
          limit: pageSize,
          offset: offset,
        );
      });

  @override
  Future<ReadingPassage?> passageById(int id) =>
      runDbGuarded('READING_PASSAGE', () => _dao.passageById(id));

  @override
  Future<List<ReadingQuestion>> questionsWithOptions(int passageId) =>
      runDbGuarded('READING_QUESTIONS', () => _dao.questionsWithOptions(passageId));

  @override
  Future<ReadingQuestion?> questionById(int id) =>
      runDbGuarded('READING_QUESTION', () => _dao.questionById(id));

  @override
  Future<List<String>> topics() =>
      runDbGuarded('READING_TOPICS', _dao.distinctTopics);

  @override
  Future<int> countPassages() =>
      runDbGuarded('READING_COUNT', _dao.countPassages);

  @override
  Future<int> countQuestions() =>
      runDbGuarded('READING_QUESTION_COUNT', _dao.countQuestions);
}
