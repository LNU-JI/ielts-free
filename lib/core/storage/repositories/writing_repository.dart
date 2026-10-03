/// Writing repository — the only data interface the domain layer may use for
/// the writing module.
///
/// It combines the **read-only content** DAO ([WritingDao]) with the
/// **writable user** DAOs ([WritingAttemptDao] for attempts and
/// [PhraseBookDao] for collected phrases). Content is never written here.
library;

import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/phrase_entry.dart';
import 'package:ielts_free/core/models/writing_attempt.dart';
import 'package:ielts_free/core/models/writing_phrase.dart';
import 'package:ielts_free/core/models/writing_sample.dart';
import 'package:ielts_free/core/models/writing_task.dart';
import 'package:ielts_free/core/storage/dao/content/writing_dao.dart';
import 'package:ielts_free/core/storage/dao/user/phrase_book_dao.dart';
import 'package:ielts_free/core/storage/dao/user/writing_attempt_dao.dart';
import 'package:ielts_free/core/storage/paging.dart';

/// Read access to writing content and read/write access to writing progress.
abstract interface class WritingRepository {
  /// A page of tasks, optionally filtered by [task] number (1 or 2).
  Future<PagedList<WritingTask>> listTasks({
    int page = 1,
    int pageSize = 20,
    int? task,
  });

  /// A task with its model essays attached, or `null` when it does not exist.
  Future<WritingTask?> taskDetail(int taskId);

  /// A random task, optionally restricted to [task] number.
  Future<WritingTask?> randomTask({int? task});

  /// Total number of tasks (respecting an optional [task] filter).
  Future<int> countTasks({int? task});

  /// A page of phrases, optionally filtered by [category] and [task].
  Future<PagedList<WritingPhrase>> phrases({
    int page = 1,
    int pageSize = 20,
    String? category,
    int? task,
  });

  /// All distinct phrase categories (for filter chips).
  Future<List<String>> phraseCategories();

  /// Collects a phrase into the phrase book and returns its row id.
  Future<int> bookmarkPhrase(PhraseEntry entry);

  /// A page of collected phrases, optionally filtered by [category].
  Future<PagedList<PhraseEntry>> bookmarkedPhrases(
    String userId, {
    int page = 1,
    int pageSize = 20,
    String? category,
  });

  /// Deletes a collected phrase.
  Future<void> deletePhrase(int id);

  /// Saves one writing attempt and returns its row id.
  Future<int> saveAttempt(WritingAttempt attempt);

  /// The most recent attempts for one task, newest first.
  Future<List<WritingAttempt>> attemptsForTask(
    String userId,
    int taskId, {
    int limit = 5,
  });

  /// The most recent attempt for one task, or `null`.
  Future<WritingAttempt?> latestAttempt(String userId, int taskId);

  /// Total words written, optionally restricted to one task number.
  Future<int> totalWordCount(String userId, {int? taskNumber});
}

/// SQLite-backed [WritingRepository].
class SqliteWritingRepository implements WritingRepository {
  SqliteWritingRepository({
    required WritingDao content,
    required WritingAttemptDao attempts,
    required PhraseBookDao phrases,
  })  : _content = content,
        _attempts = attempts,
        _phrases = phrases;

  final WritingDao _content;
  final WritingAttemptDao _attempts;
  final PhraseBookDao _phrases;

  @override
  Future<PagedList<WritingTask>> listTasks({
    int page = 1,
    int pageSize = 20,
    int? task,
  }) =>
      runDbGuarded('WRITING_LIST', () async {
        final int safePage = page < 1 ? 1 : page;
        final int offset = (safePage - 1) * pageSize;
        final List<WritingTask> items =
            await _content.page(limit: pageSize, offset: offset, task: task);
        final int total = await _content.countTasks(task: task);
        return PagedList<WritingTask>(
          items: items,
          total: total,
          limit: pageSize,
          offset: offset,
        );
      });

  @override
  Future<WritingTask?> taskDetail(int taskId) =>
      runDbGuarded('WRITING_TASK_DETAIL', () async {
        final WritingTask? task = await _content.taskById(taskId);
        if (task == null) {
          return null;
        }
        final List<WritingSample> samples =
            await _content.samplesForTask(taskId);
        return task.withSamples(samples);
      });

  @override
  Future<WritingTask?> randomTask({int? task}) =>
      runDbGuarded('WRITING_RANDOM', () => _content.randomTask(task: task));

  @override
  Future<int> countTasks({int? task}) =>
      runDbGuarded('WRITING_COUNT', () => _content.countTasks(task: task));

  @override
  Future<PagedList<WritingPhrase>> phrases({
    int page = 1,
    int pageSize = 20,
    String? category,
    int? task,
  }) =>
      runDbGuarded('WRITING_PHRASES', () async {
        final int safePage = page < 1 ? 1 : page;
        final int offset = (safePage - 1) * pageSize;
        final List<WritingPhrase> items = await _content.phrases(
          limit: pageSize,
          offset: offset,
          category: category,
          task: task,
        );
        final int total =
            await _content.countPhrases(category: category, task: task);
        return PagedList<WritingPhrase>(
          items: items,
          total: total,
          limit: pageSize,
          offset: offset,
        );
      });

  @override
  Future<List<String>> phraseCategories() =>
      runDbGuarded('WRITING_PHRASE_CATEGORIES', _content.distinctCategories);

  @override
  Future<int> bookmarkPhrase(PhraseEntry entry) =>
      runDbGuarded('PHRASE_BOOK_ADD', () => _phrases.add(entry));

  @override
  Future<PagedList<PhraseEntry>> bookmarkedPhrases(
    String userId, {
    int page = 1,
    int pageSize = 20,
    String? category,
  }) =>
      runDbGuarded('PHRASE_BOOK_LIST', () async {
        final int safePage = page < 1 ? 1 : page;
        final int offset = (safePage - 1) * pageSize;
        final List<PhraseEntry> items = await _phrases.list(
          userId,
          limit: pageSize,
          offset: offset,
          category: category,
        );
        final int total = await _phrases.count(userId, category: category);
        return PagedList<PhraseEntry>(
          items: items,
          total: total,
          limit: pageSize,
          offset: offset,
        );
      });

  @override
  Future<void> deletePhrase(int id) =>
      runDbGuarded('PHRASE_BOOK_DELETE', () => _phrases.delete(id));

  @override
  Future<int> saveAttempt(WritingAttempt attempt) =>
      runDbGuarded('WRITING_ATTEMPT_SAVE', () => _attempts.insert(attempt));

  @override
  Future<List<WritingAttempt>> attemptsForTask(
    String userId,
    int taskId, {
    int limit = 5,
  }) =>
      runDbGuarded(
        'WRITING_ATTEMPT_LIST',
        () => _attempts.recentForTask(userId, taskId, limit: limit),
      );

  @override
  Future<WritingAttempt?> latestAttempt(String userId, int taskId) =>
      runDbGuarded(
        'WRITING_ATTEMPT_LATEST',
        () => _attempts.latestForTask(userId, taskId),
      );

  @override
  Future<int> totalWordCount(String userId, {int? taskNumber}) => runDbGuarded(
        'WRITING_TOTAL_WORDS',
        () => _attempts.totalWordCount(userId, taskNumber: taskNumber),
      );
}
