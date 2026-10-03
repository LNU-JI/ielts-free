/// Listening repository — the only data interface the domain layer may use for
/// the listening module.
///
/// It combines the **read-only content** DAO ([ListeningDao]) with the
/// **writable user** DAOs ([ListeningErrorDao] for the error log and
/// [SentenceBookDao] for bookmarked sentences). Content is never written here;
/// user rows are never mixed into the content tables.
library;

import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/enums/listening_error_type.dart';
import 'package:ielts_free/core/models/listening_cue.dart';
import 'package:ielts_free/core/models/listening_error.dart';
import 'package:ielts_free/core/models/listening_question.dart';
import 'package:ielts_free/core/models/listening_section.dart';
import 'package:ielts_free/core/models/sentence_entry.dart';
import 'package:ielts_free/core/storage/dao/content/listening_dao.dart';
import 'package:ielts_free/core/storage/dao/user/listening_error_dao.dart';
import 'package:ielts_free/core/storage/dao/user/sentence_book_dao.dart';
import 'package:ielts_free/core/storage/paging.dart';

/// A listening section together with the cues and questions to practise it.
class ListeningSectionDetail {
  const ListeningSectionDetail({
    required this.section,
    required this.cues,
    required this.questions,
  });

  /// The section itself.
  final ListeningSection section;

  /// The spoken lines, ordered for sentence-by-sentence practice.
  final List<ListeningCue> cues;

  /// The questions attached to the section.
  final List<ListeningQuestion> questions;
}

/// Read access to listening content and read/write access to listening progress.
abstract interface class ListeningRepository {
  /// A page of sections, optionally filtered by IELTS [part] (1–4).
  Future<PagedList<ListeningSection>> listSections({
    int page = 1,
    int pageSize = 20,
    int? part,
  });

  /// A section with its cues and questions, or `null` when it does not exist.
  Future<ListeningSectionDetail?> sectionDetail(int sectionId);

  /// A random section, optionally restricted to [part].
  Future<ListeningSection?> randomSection({int? part});

  /// Total number of sections (respecting an optional [part] filter).
  Future<int> countSections({int? part});

  /// Records one listening error and returns its row id.
  Future<int> recordError(ListeningError error);

  /// Errors logged for one section, newest first.
  Future<List<ListeningError>> errorsForSection(String userId, int sectionId);

  /// Errors grouped by [ListeningErrorType], optionally scoped to one section.
  Future<Map<ListeningErrorType, int>> errorStats(
    String userId, {
    int? sectionId,
  });

  /// Deletes every error logged for one section.
  Future<void> clearErrors(String userId, int sectionId);

  /// Bookmarks a sentence and returns its row id.
  Future<int> bookmarkSentence(SentenceEntry entry);

  /// A page of bookmarked sentences, optionally filtered by [sourceType].
  Future<PagedList<SentenceEntry>> sentences(
    String userId, {
    int page = 1,
    int pageSize = 20,
    String? sourceType,
    bool? mastered,
  });

  /// Sets the mastered flag of a bookmarked sentence.
  Future<void> markSentenceMastered(int id, bool mastered);

  /// Increments the review counter of a bookmarked sentence.
  Future<void> incrementSentenceReview(int id);

  /// Deletes a bookmarked sentence.
  Future<void> deleteSentence(int id);
}

/// SQLite-backed [ListeningRepository].
class SqliteListeningRepository implements ListeningRepository {
  SqliteListeningRepository({
    required ListeningDao content,
    required ListeningErrorDao errors,
    required SentenceBookDao sentences,
  })  : _content = content,
        _errors = errors,
        _sentences = sentences;

  final ListeningDao _content;
  final ListeningErrorDao _errors;
  final SentenceBookDao _sentences;

  @override
  Future<PagedList<ListeningSection>> listSections({
    int page = 1,
    int pageSize = 20,
    int? part,
  }) =>
      runDbGuarded('LISTENING_LIST', () async {
        final int safePage = page < 1 ? 1 : page;
        final int offset = (safePage - 1) * pageSize;
        final List<ListeningSection> items =
            await _content.page(limit: pageSize, offset: offset, part: part);
        final int total = await _content.countSections(part: part);
        return PagedList<ListeningSection>(
          items: items,
          total: total,
          limit: pageSize,
          offset: offset,
        );
      });

  @override
  Future<ListeningSectionDetail?> sectionDetail(int sectionId) =>
      runDbGuarded('LISTENING_SECTION_DETAIL', () async {
        final ListeningSection? section = await _content.sectionById(sectionId);
        if (section == null) {
          return null;
        }
        final List<ListeningCue> cues = await _content.cuesForSection(sectionId);
        final List<ListeningQuestion> questions =
            await _content.questionsForSection(sectionId);
        return ListeningSectionDetail(
          section: section,
          cues: cues,
          questions: questions,
        );
      });

  @override
  Future<ListeningSection?> randomSection({int? part}) =>
      runDbGuarded('LISTENING_RANDOM', () => _content.randomSection(part: part));

  @override
  Future<int> countSections({int? part}) =>
      runDbGuarded('LISTENING_COUNT', () => _content.countSections(part: part));

  @override
  Future<int> recordError(ListeningError error) =>
      runDbGuarded('LISTENING_ERROR_RECORD', () => _errors.insert(error));

  @override
  Future<List<ListeningError>> errorsForSection(
    String userId,
    int sectionId,
  ) =>
      runDbGuarded(
        'LISTENING_ERROR_LIST',
        () => _errors.forSection(userId, sectionId),
      );

  @override
  Future<Map<ListeningErrorType, int>> errorStats(
    String userId, {
    int? sectionId,
  }) =>
      runDbGuarded(
        'LISTENING_ERROR_STATS',
        () => _errors.countByType(userId, sectionId: sectionId),
      );

  @override
  Future<void> clearErrors(String userId, int sectionId) => runDbGuarded(
        'LISTENING_ERROR_CLEAR',
        () => _errors.clearForSection(userId, sectionId),
      );

  @override
  Future<int> bookmarkSentence(SentenceEntry entry) =>
      runDbGuarded('SENTENCE_BOOK_ADD', () => _sentences.add(entry));

  @override
  Future<PagedList<SentenceEntry>> sentences(
    String userId, {
    int page = 1,
    int pageSize = 20,
    String? sourceType,
    bool? mastered,
  }) =>
      runDbGuarded('SENTENCE_BOOK_LIST', () async {
        final int safePage = page < 1 ? 1 : page;
        final int offset = (safePage - 1) * pageSize;
        final List<SentenceEntry> items = await _sentences.list(
          userId,
          limit: pageSize,
          offset: offset,
          sourceType: sourceType,
          mastered: mastered,
        );
        final int total = await _sentences.count(
          userId,
          sourceType: sourceType,
          mastered: mastered,
        );
        return PagedList<SentenceEntry>(
          items: items,
          total: total,
          limit: pageSize,
          offset: offset,
        );
      });

  @override
  Future<void> markSentenceMastered(int id, bool mastered) => runDbGuarded(
        'SENTENCE_BOOK_MASTERED',
        () => _sentences.markMastered(id, mastered),
      );

  @override
  Future<void> incrementSentenceReview(int id) => runDbGuarded(
        'SENTENCE_BOOK_REVIEW',
        () => _sentences.incrementReview(id),
      );

  @override
  Future<void> deleteSentence(int id) =>
      runDbGuarded('SENTENCE_BOOK_DELETE', () => _sentences.delete(id));
}
