/// Speaking repository — the only data interface the domain layer may use for
/// the speaking module.
///
/// It combines the **read-only content** DAO ([SpeakingDao]) with the
/// **writable user** DAO ([SpeakingAttemptDao]). Content is never written here.
library;

import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/enums/speaking_part.dart';
import 'package:ielts_free/core/models/speaking_attempt.dart';
import 'package:ielts_free/core/models/speaking_question.dart';
import 'package:ielts_free/core/models/speaking_topic.dart';
import 'package:ielts_free/core/storage/dao/content/speaking_dao.dart';
import 'package:ielts_free/core/storage/dao/user/speaking_attempt_dao.dart';
import 'package:ielts_free/core/storage/paging.dart';

/// Read access to speaking content and read/write access to speaking progress.
abstract interface class SpeakingRepository {
  /// A page of topics, optionally filtered by [part].
  Future<PagedList<SpeakingTopic>> listTopics({
    int page = 1,
    int pageSize = 20,
    SpeakingPart? part,
  });

  /// A topic with its questions attached, or `null` when it does not exist.
  Future<SpeakingTopic?> topicDetail(int topicId);

  /// A random topic, optionally restricted to [part].
  Future<SpeakingTopic?> randomTopic({SpeakingPart? part});

  /// Total number of topics (respecting an optional [part] filter).
  Future<int> countTopics({SpeakingPart? part});

  /// Records one practice attempt and returns its row id.
  Future<int> recordAttempt(SpeakingAttempt attempt);

  /// The most recent attempts for one question, newest first.
  Future<List<SpeakingAttempt>> attemptsForQuestion(
    String userId,
    int questionId, {
    int limit = 5,
  });

  /// Total seconds spoken, optionally restricted to one [part].
  Future<int> totalPracticeSeconds(String userId, {SpeakingPart? part});

  /// Number of attempts, optionally restricted to one [part].
  Future<int> attemptCount(String userId, {SpeakingPart? part});
}

/// SQLite-backed [SpeakingRepository].
class SqliteSpeakingRepository implements SpeakingRepository {
  SqliteSpeakingRepository({
    required SpeakingDao content,
    required SpeakingAttemptDao attempts,
  })  : _content = content,
        _attempts = attempts;

  final SpeakingDao _content;
  final SpeakingAttemptDao _attempts;

  @override
  Future<PagedList<SpeakingTopic>> listTopics({
    int page = 1,
    int pageSize = 20,
    SpeakingPart? part,
  }) =>
      runDbGuarded('SPEAKING_LIST', () async {
        final int safePage = page < 1 ? 1 : page;
        final int offset = (safePage - 1) * pageSize;
        final List<SpeakingTopic> items = await _content.page(
          limit: pageSize,
          offset: offset,
          part: part?.wire,
        );
        final int total = await _content.countTopics(part: part?.wire);
        return PagedList<SpeakingTopic>(
          items: items,
          total: total,
          limit: pageSize,
          offset: offset,
        );
      });

  @override
  Future<SpeakingTopic?> topicDetail(int topicId) =>
      runDbGuarded('SPEAKING_TOPIC_DETAIL', () async {
        final SpeakingTopic? topic = await _content.topicById(topicId);
        if (topic == null) {
          return null;
        }
        final List<SpeakingQuestion> questions =
            await _content.questionsForTopic(topicId);
        return topic.withQuestions(questions);
      });

  @override
  Future<SpeakingTopic?> randomTopic({SpeakingPart? part}) =>
      runDbGuarded('SPEAKING_RANDOM', () => _content.randomTopic(part: part?.wire));

  @override
  Future<int> countTopics({SpeakingPart? part}) =>
      runDbGuarded('SPEAKING_COUNT', () => _content.countTopics(part: part?.wire));

  @override
  Future<int> recordAttempt(SpeakingAttempt attempt) =>
      runDbGuarded('SPEAKING_ATTEMPT_RECORD', () => _attempts.insert(attempt));

  @override
  Future<List<SpeakingAttempt>> attemptsForQuestion(
    String userId,
    int questionId, {
    int limit = 5,
  }) =>
      runDbGuarded(
        'SPEAKING_ATTEMPT_LIST',
        () => _attempts.recentForQuestion(userId, questionId, limit: limit),
      );

  @override
  Future<int> totalPracticeSeconds(String userId, {SpeakingPart? part}) =>
      runDbGuarded(
        'SPEAKING_TOTAL_SECONDS',
        () => _attempts.totalDurationSec(userId, part: part?.wire),
      );

  @override
  Future<int> attemptCount(String userId, {SpeakingPart? part}) => runDbGuarded(
        'SPEAKING_ATTEMPT_COUNT',
        () => _attempts.countAttempts(userId, part: part?.wire),
      );
}
