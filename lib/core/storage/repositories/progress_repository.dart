/// Progress repository — vocabulary memory, answers, skill scores, statistics
/// and sessions.
///
/// This is the write path of the adaptive loop: answers are recorded, mistakes
/// are derived (via [MistakeRepository]) and skill scores / statistics are
/// updated (docs/BRIEF.md §77, ARCHITECTURE §5).
library;

import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/learning_session.dart';
import 'package:ielts_free/core/models/learning_statistics.dart';
import 'package:ielts_free/core/models/skill_score.dart';
import 'package:ielts_free/core/models/user_answer.dart';
import 'package:ielts_free/core/models/vocabulary_review.dart';
import 'package:ielts_free/core/storage/dao/user/session_dao.dart';
import 'package:ielts_free/core/storage/dao/user/skill_score_dao.dart';
import 'package:ielts_free/core/storage/dao/user/statistics_dao.dart';
import 'package:ielts_free/core/storage/dao/user/user_answer_dao.dart';
import 'package:ielts_free/core/storage/dao/user/vocabulary_review_dao.dart';
import 'package:ielts_free/core/storage/paging.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// Read/write access to learning progress.
abstract interface class ProgressRepository {
  // --- Vocabulary memory ---------------------------------------------------

  /// The review state of one word, or `null`.
  Future<VocabularyReview?> reviewFor(String userId, int vocabularyId);

  /// Saves a review state (insert or update).
  Future<void> saveReview(VocabularyReview review);

  /// A page of words due for review.
  Future<PagedList<VocabularyReview>> dueReviews(
    String userId, {
    int page = 1,
    int pageSize = 20,
  });

  /// Number of words due for review.
  Future<int> countDue(String userId);

  /// Sets the favourite flag for a word.
  Future<void> setFavorite(String userId, int vocabularyId, bool favorite);

  /// Number of mastered words.
  Future<int> countMastered(String userId);

  // --- Answers -------------------------------------------------------------

  /// Records one answer and returns its id.
  Future<int> recordAnswer(UserAnswer answer);

  /// The most recent answers, optionally filtered by skill.
  Future<List<UserAnswer>> recentAnswers(
    String userId, {
    int limit = 20,
    SkillType? skill,
  });

  // --- Skill scores --------------------------------------------------------

  /// All skill-score rows for [userId].
  Future<List<SkillScore>> allSkillScores(String userId);

  /// A `skill → score` map for [userId].
  Future<Map<SkillType, double>> skillScoreMap(String userId);

  /// Saves one skill score.
  Future<void> saveSkillScore(SkillScore score);

  // --- Statistics ----------------------------------------------------------

  /// Today's statistics row, or `null`.
  Future<LearningStatistics?> todayStatistics(String userId);

  /// Saves a statistics row.
  Future<void> saveStatistics(LearningStatistics stats);

  // --- Sessions ------------------------------------------------------------

  /// The most recent active session, or `null`.
  Future<LearningSession?> activeSession(String userId);

  /// Inserts or updates a session.
  Future<void> saveSession(LearningSession session);

  /// Deletes a session.
  Future<void> deleteSession(String id);
}

/// SQLite-backed [ProgressRepository].
class SqliteProgressRepository implements ProgressRepository {
  SqliteProgressRepository({
    required VocabularyReviewDao reviewDao,
    required UserAnswerDao answerDao,
    required SkillScoreDao skillScoreDao,
    required StatisticsDao statisticsDao,
    required SessionDao sessionDao,
  })  : _reviewDao = reviewDao,
        _answerDao = answerDao,
        _skillScoreDao = skillScoreDao,
        _statisticsDao = statisticsDao,
        _sessionDao = sessionDao;

  final VocabularyReviewDao _reviewDao;
  final UserAnswerDao _answerDao;
  final SkillScoreDao _skillScoreDao;
  final StatisticsDao _statisticsDao;
  final SessionDao _sessionDao;

  @override
  Future<VocabularyReview?> reviewFor(String userId, int vocabularyId) =>
      runDbGuarded('PROGRESS_REVIEW', () => _reviewDao.byVocabulary(userId, vocabularyId));

  @override
  Future<void> saveReview(VocabularyReview review) =>
      runDbGuarded('PROGRESS_SAVE_REVIEW', () => _reviewDao.upsert(review));

  @override
  Future<PagedList<VocabularyReview>> dueReviews(
    String userId, {
    int page = 1,
    int pageSize = 20,
  }) =>
      runDbGuarded('PROGRESS_DUE', () async {
        final int safePage = page < 1 ? 1 : page;
        final int offset = (safePage - 1) * pageSize;
        final List<VocabularyReview> items =
            await _reviewDao.due(userId, limit: pageSize, offset: offset);
        final int total = await _reviewDao.countDue(userId);
        return PagedList<VocabularyReview>(
          items: items,
          total: total,
          limit: pageSize,
          offset: offset,
        );
      });

  @override
  Future<int> countDue(String userId) =>
      runDbGuarded('PROGRESS_COUNT_DUE', () => _reviewDao.countDue(userId));

  @override
  Future<void> setFavorite(String userId, int vocabularyId, bool favorite) =>
      runDbGuarded(
        'PROGRESS_FAVORITE',
        () => _reviewDao.setFavorite(userId, vocabularyId, favorite),
      );

  @override
  Future<int> countMastered(String userId) =>
      runDbGuarded('PROGRESS_MASTERED', () => _reviewDao.countMastered(userId));

  @override
  Future<int> recordAnswer(UserAnswer answer) =>
      runDbGuarded('PROGRESS_ANSWER', () => _answerDao.insert(answer));

  @override
  Future<List<UserAnswer>> recentAnswers(
    String userId, {
    int limit = 20,
    SkillType? skill,
  }) =>
      runDbGuarded(
        'PROGRESS_RECENT_ANSWERS',
        () => _answerDao.recent(userId, limit: limit, skill: skill),
      );

  @override
  Future<List<SkillScore>> allSkillScores(String userId) =>
      runDbGuarded('PROGRESS_SCORES', () => _skillScoreDao.forUser(userId));

  @override
  Future<Map<SkillType, double>> skillScoreMap(String userId) =>
      runDbGuarded('PROGRESS_SCORE_MAP', () => _skillScoreDao.scoreMap(userId));

  @override
  Future<void> saveSkillScore(SkillScore score) =>
      runDbGuarded('PROGRESS_SAVE_SCORE', () => _skillScoreDao.upsert(score));

  @override
  Future<LearningStatistics?> todayStatistics(String userId) => runDbGuarded(
        'PROGRESS_TODAY',
        () => _statisticsDao.forDate(
          userId,
          AppDateUtils.todayLocalDateString(),
        ),
      );

  @override
  Future<void> saveStatistics(LearningStatistics stats) =>
      runDbGuarded('PROGRESS_SAVE_STATS', () => _statisticsDao.upsert(stats));

  @override
  Future<LearningSession?> activeSession(String userId) =>
      runDbGuarded('PROGRESS_ACTIVE_SESSION', () => _sessionDao.activeForUser(userId));

  @override
  Future<void> saveSession(LearningSession session) =>
      runDbGuarded('PROGRESS_SAVE_SESSION', () async {
        final LearningSession? existing = await _sessionDao.byId(session.id);
        if (existing == null) {
          await _sessionDao.insert(session);
        } else {
          await _sessionDao.update(session);
        }
      });

  @override
  Future<void> deleteSession(String id) =>
      runDbGuarded('PROGRESS_DELETE_SESSION', () => _sessionDao.delete(id));
}
