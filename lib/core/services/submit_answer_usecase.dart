/// Unified answer-persistence use case — **the single write path of the adaptive
/// loop** (docs/BRIEF.md §94, ARCHITECTURE §6.2 阅读闭环 / §6.3 词汇记忆).
///
/// Every answer the user submits (a vocabulary question, a reading question, or a
/// mistake redo) flows through [SubmitAnswerUseCase]. It grades the answer with
/// the pure T03 services and then performs **all** derived writes inside a single
/// `db.transaction()`, so the loop can never be left half-updated:
///
/// 1. `user_answers` — the raw answer event;
/// 2. grading — via [GradingService] (pure, run before the transaction);
/// 3. `mistakes` — wrong answers upsert a mistake (`wrongCount + 1`,
///    `lastWrongAt`, §29 [ErrorType]); a correct **redo** evolves `mastery`;
/// 4. `vocabulary_reviews` — vocabulary questions update the spaced-repetition
///    state through [MemoryService] (`memoryLevel ± 1`, `nextReviewAt`);
/// 5. `skill_scores` — recomputed from the recent-answers window (N = 20) with
///    [SkillScoreService];
/// 6. difficulty — [DifficultyService] raises / lowers / focuses the skill's
///    `current_difficulty`;
/// 7. priority — [PriorityService] re-evaluates the skill and the value is
///    written onto today's matching `daily_tasks.payload`;
/// 8. `learning_statistics` + `streak` — today's row is updated and the streak
///    advanced via [StreakService];
/// 9. `daily_tasks` — the matching task's `completedCount` / `status` advance.
///
/// The **only** thing done *after* the transaction commits is `notifyDataChanged`
/// — and that is the caller's job (the controller owns the `Ref`), so Dashboard /
/// Study Plan recompute from committed data (FR-064).
///
/// ### Why raw `Transaction` operations (not the DAOs)
/// The DAOs open their own transactions for read-then-write upserts
/// (`MistakeDao.recordWrong`, `DailyTaskDao.replaceForDate`). sqflite does not
/// support nested transactions, so calling them inside this transaction would
/// deadlock. This use case therefore issues its statements directly on the
/// `Transaction`, which keeps every write atomic *and* avoids nesting.
library;

import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/enums/error_type.dart';
import 'package:ielts_free/core/models/enums/question_type.dart';
import 'package:ielts_free/core/models/enums/ref_type.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/enums/task_status.dart';
import 'package:ielts_free/core/models/enums/task_type.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/models/reading_question.dart';
import 'package:ielts_free/core/models/skill_score.dart';
import 'package:ielts_free/core/models/vocabulary_review.dart';
import 'package:ielts_free/core/services/adaptive/adaptive_models.dart';
import 'package:ielts_free/core/services/adaptive/difficulty_service.dart';
import 'package:ielts_free/core/services/adaptive/mastery_service.dart';
import 'package:ielts_free/core/services/adaptive/memory_service.dart';
import 'package:ielts_free/core/services/adaptive/priority_service.dart';
import 'package:ielts_free/core/services/adaptive/skill_score_service.dart';
import 'package:ielts_free/core/services/adaptive/streak_service.dart';
import 'package:ielts_free/core/services/clock_service.dart';
import 'package:ielts_free/core/services/grading_service.dart';
import 'package:ielts_free/core/services/mistake_classifier.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// One answer to be persisted.
///
/// Callers normally build this through [SubmitAnswerUseCase.submitVocabulary] or
/// [SubmitAnswerUseCase.submitReading], which grade first. The plain
/// [SubmitAnswerUseCase.submit] entry point accepts an already-graded answer and
/// is used by the mistake-redo flow.
class AnswerSubmission {
  const AnswerSubmission({
    required this.userId,
    required this.refType,
    required this.refId,
    required this.skill,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    this.difficulty = 3,
    this.timeSpentMs = 0,
    this.sessionId,
    this.answeredAt,
    this.errorType,
    this.questionType,
    this.isRedo = false,
    this.mistakeId,
  });

  /// Owning user id.
  final String userId;

  /// Whether the answer is for a word or a reading question.
  final RefType refType;

  /// The referenced id (vocabulary id or reading question id).
  final int refId;

  /// The skill exercised.
  final SkillType skill;

  /// The raw answer the user gave.
  final String userAnswer;

  /// The canonical correct answer.
  final String correctAnswer;

  /// Whether the answer was correct (already graded).
  final bool isCorrect;

  /// Difficulty of the item, in `1..5`.
  final int difficulty;

  /// Time spent on the item, in milliseconds.
  final int timeSpentMs;

  /// Owning session id, when the answer belongs to a run.
  final String? sessionId;

  /// When the answer was submitted (UTC); defaults to the clock.
  final DateTime? answeredAt;

  /// The classified error type for a wrong answer (BRIEF §29).
  final ErrorType? errorType;

  /// The reading question type, when [refType] is [RefType.reading].
  final QuestionType? questionType;

  /// Whether this answer is a redo of an existing mistake.
  final bool isRedo;

  /// The mistake being redone, when [isRedo] is `true`.
  final int? mistakeId;
}

/// The outcome of persisting one answer.
class SubmitAnswerResult {
  const SubmitAnswerResult({
    required this.isCorrect,
    required this.grade,
    this.mistakeId,
    this.mastery,
    this.justMastered = false,
    this.memoryLevel,
    this.becameMastered = false,
    this.skillScore,
    this.skillDifficulty,
    this.difficultyAction,
    this.priority,
    this.streak,
    this.taskId,
  });

  /// Whether the answer was correct.
  final bool isCorrect;

  /// The full grading outcome (for feedback UI).
  final GradeResult grade;

  /// The affected mistake row id, when applicable.
  final int? mistakeId;

  /// The mistake's mastery after this event, when applicable.
  final double? mastery;

  /// Whether this event pushed the mistake across the mastery threshold.
  final bool justMastered;

  /// The vocabulary memory level after this event, when applicable.
  final int? memoryLevel;

  /// Whether a word crossed the "mastered" level on this event.
  final bool becameMastered;

  /// The recomputed skill score in `[0, 100]`, when the skill was updated.
  final double? skillScore;

  /// The skill's difficulty after this event.
  final int? skillDifficulty;

  /// The difficulty decision taken (§5.4).
  final DifficultyAction? difficultyAction;

  /// The recomputed training priority for the skill (§5.3).
  final double? priority;

  /// The study streak after this event.
  final int? streak;

  /// The daily task advanced by this event, when one matched.
  final int? taskId;
}

/// Grades and atomically persists answers, updating every derived table.
class SubmitAnswerUseCase {
  SubmitAnswerUseCase({
    required Database db,
    required GradingService gradingService,
    required MemoryService memoryService,
    required SkillScoreService skillScoreService,
    required DifficultyService difficultyService,
    required PriorityService priorityService,
    required MasteryService masteryService,
    required StreakService streakService,
    Clock clock = const SystemClock(),
    this.skillScoreWindow = 20,
    this.difficultyWindow = 3,
  })  : _db = db,
        _grading = gradingService,
        _memory = memoryService,
        _skillScore = skillScoreService,
        _difficulty = difficultyService,
        _priority = priorityService,
        _mastery = masteryService,
        _streak = streakService,
        _clock = clock;

  final Database _db;
  final GradingService _grading;
  final MemoryService _memory;
  final SkillScoreService _skillScore;
  final DifficultyService _difficulty;
  final PriorityService _priority;
  final MasteryService _mastery;
  final StreakService _streak;
  final Clock _clock;

  /// Recent-answers window for the skill score (§5.2, `N = 20`).
  final int skillScoreWindow;

  /// Trailing window for the difficulty decision (§5.4).
  final int difficultyWindow;

  /// Vocabulary memory level at or above which a word is "mastered".
  static const int masteredMemoryLevel = 4;

  /// Score used when a skill has no stored row yet (matches the seed default).
  static const double fallbackPreviousScore = 40.0;

  /// Days of wrong answers folded into the priority factor (§5.3).
  static const int errorWindowDays = 14;

  // --- convenience entry points (grade first) -----------------------------

  /// Grades and persists a vocabulary practice answer.
  Future<SubmitAnswerResult> submitVocabulary({
    required String userId,
    required int vocabularyId,
    required VocabQuestionKind kind,
    required String expected,
    required String actual,
    int difficulty = 3,
    int timeSpentMs = 0,
    String? sessionId,
    DateTime? answeredAt,
    bool isRedo = false,
    int? mistakeId,
  }) {
    final GradeResult grade = _grading.gradeVocabulary(
      kind: kind,
      expected: expected,
      actual: actual,
    );
    return submit(
      AnswerSubmission(
        userId: userId,
        refType: RefType.vocabulary,
        refId: vocabularyId,
        skill: SkillType.vocabulary,
        userAnswer: actual,
        correctAnswer: expected,
        isCorrect: grade.isCorrect,
        difficulty: difficulty,
        timeSpentMs: timeSpentMs,
        sessionId: sessionId,
        answeredAt: answeredAt,
        errorType: grade.isCorrect ? null : MistakeClassifier.forVocabulary(kind),
        isRedo: isRedo,
        mistakeId: mistakeId,
      ),
      grade: grade,
    );
  }

  /// Grades and persists a reading answer.
  Future<SubmitAnswerResult> submitReading({
    required String userId,
    required ReadingQuestion question,
    required String userAnswer,
    int timeSpentMs = 0,
    String? sessionId,
    DateTime? answeredAt,
    bool isRedo = false,
    int? mistakeId,
  }) {
    final GradeResult grade = _grading.gradeReading(
      type: question.questionType,
      correctAnswer: question.correctAnswer,
      userAnswer: userAnswer,
      options: question.options,
    );
    return submit(
      AnswerSubmission(
        userId: userId,
        refType: RefType.reading,
        refId: question.id,
        skill: question.skill ?? SkillType.reading,
        userAnswer: userAnswer,
        correctAnswer: question.correctAnswer,
        isCorrect: grade.isCorrect,
        difficulty: question.difficulty,
        timeSpentMs: timeSpentMs,
        sessionId: sessionId,
        answeredAt: answeredAt,
        errorType:
            grade.isCorrect ? null : MistakeClassifier.forReading(question.questionType),
        questionType: question.questionType,
        isRedo: isRedo,
        mistakeId: mistakeId,
      ),
      grade: grade,
    );
  }

  // --- core ---------------------------------------------------------------

  /// Persists [submission] atomically and returns what changed.
  ///
  /// [grade] lets the convenience methods pass the grading outcome through so it
  /// is not recomputed; when omitted a synthetic result is built from
  /// [AnswerSubmission.isCorrect].
  Future<SubmitAnswerResult> submit(
    AnswerSubmission submission, {
    GradeResult? grade,
  }) {
    final GradeResult effectiveGrade = grade ??
        (submission.isCorrect
            ? const GradeResult(
                isCorrect: true,
                matchKind: MatchKind.exact,
                normalizedExpected: '',
                normalizedActual: '',
              )
            : GradeResult.wrong);

    return runDbGuarded('SUBMIT_ANSWER', () async {
      final DateTime now = (submission.answeredAt ?? _clock.now()).toUtc();
      final String stamp = AppDateUtils.toUtcIso(now);
      final String today = AppDateUtils.localDateString(now);
      final String userId = submission.userId;

      return _db.transaction<SubmitAnswerResult>((Transaction txn) async {
        // 0. Foreign-key anchor: `users` must exist before any dependent row.
        await txn.insert(
          'users',
          <String, Object?>{'id': userId, 'created_at': stamp},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        // 1. Raw answer event.
        await txn.insert('user_answers', <String, Object?>{
          'user_id': userId,
          'ref_type': submission.refType.wire,
          'ref_id': submission.refId,
          'skill': submission.skill.wire,
          'user_answer': submission.userAnswer,
          'is_correct': submission.isCorrect ? 1 : 0,
          'difficulty': submission.difficulty,
          'time_spent_ms': submission.timeSpentMs,
          'session_id': submission.sessionId,
          'answered_at': stamp,
        });

        // 2. (grading already done above — pure, no IO)

        // 3. Mistakes.
        final _MistakeOutcome mistake = await _applyMistake(
          txn,
          submission,
          stamp,
        );

        // 4. Vocabulary memory.
        final _MemoryOutcome memory = await _applyMemory(
          txn,
          submission,
          now,
          stamp,
        );

        // 5. + 6. Skill score and difficulty.
        final _SkillOutcome skill = await _applySkill(
          txn,
          submission,
          now,
          stamp,
        );

        // 7. Priority (derived; written onto today's task payload).
        final double priority = await _computePriority(
          txn,
          submission,
          now,
        );

        // 8. Statistics + streak.
        final int streak = await _applyStatistics(
          txn,
          submission,
          memory,
          today,
          now,
          stamp,
        );

        // 9. Daily task progress (+ refreshed priority in the payload).
        final int? taskId = await _applyDailyTask(
          txn,
          submission,
          today,
          stamp,
          priority,
        );

        return SubmitAnswerResult(
          isCorrect: submission.isCorrect,
          grade: effectiveGrade,
          mistakeId: mistake.mistakeId,
          mastery: mistake.mastery,
          justMastered: mistake.justMastered,
          memoryLevel: memory.memoryLevel,
          becameMastered: memory.becameMastered,
          skillScore: skill.score,
          skillDifficulty: skill.difficulty,
          difficultyAction: skill.action,
          priority: priority,
          streak: streak,
          taskId: taskId,
        );
      });
    });
  }

  // --- step 3: mistakes ---------------------------------------------------

  Future<_MistakeOutcome> _applyMistake(
    Transaction txn,
    AnswerSubmission submission,
    String stamp,
  ) async {
    final String userId = submission.userId;

    // Correct redo of a known mistake → evolve mastery upward.
    if (submission.isCorrect && submission.isRedo && submission.mistakeId != null) {
      final List<Map<String, Object?>> rows = await txn.query(
        'mistakes',
        columns: <String>['id', 'mastery'],
        where: 'id = ?',
        whereArgs: <Object?>[submission.mistakeId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const _MistakeOutcome();
      }
      final double before = doubleOrDefault(rows.first['mastery'], 0);
      final MasteryResult evolve =
          _mastery.evolve(mastery: before, correct: true);
      await txn.update(
        'mistakes',
        <String, Object?>{
          'mastery': evolve.mastery,
          'updated_at': stamp,
        },
        where: 'id = ?',
        whereArgs: <Object?>[submission.mistakeId],
      );
      return _MistakeOutcome(
        mistakeId: submission.mistakeId,
        mastery: evolve.mastery,
        justMastered: evolve.justMastered,
      );
    }

    // Only wrong answers create / bump a mistake.
    if (submission.isCorrect) {
      return const _MistakeOutcome();
    }

    final List<Map<String, Object?>> existing = await txn.query(
      'mistakes',
      columns: <String>['id', 'mastery', 'wrong_count'],
      where: 'user_id = ? AND ref_type = ? AND ref_id = ?',
      whereArgs: <Object?>[userId, submission.refType.wire, submission.refId],
      limit: 1,
    );

    final double masteryBefore =
        existing.isEmpty ? 0.0 : doubleOrDefault(existing.first['mastery'], 0);
    final MasteryResult evolve =
        _mastery.evolve(mastery: masteryBefore, correct: false);

    if (existing.isEmpty) {
      final int id = await txn.insert('mistakes', <String, Object?>{
        'user_id': userId,
        'ref_type': submission.refType.wire,
        'ref_id': submission.refId,
        'question_type': submission.questionType?.wire,
        'skill': submission.skill.wire,
        'user_answer': submission.userAnswer,
        'correct_answer': submission.correctAnswer,
        'error_type': submission.errorType?.wire,
        'difficulty': submission.difficulty,
        'wrong_count': 1,
        'last_wrong_at': stamp,
        'mastery': evolve.mastery,
        'created_at': stamp,
        'updated_at': stamp,
      });
      return _MistakeOutcome(mistakeId: id, mastery: evolve.mastery);
    }

    final int id = intOrDefault(existing.first['id'], 0);
    final int previous = intOrDefault(existing.first['wrong_count'], 1);
    await txn.update(
      'mistakes',
      <String, Object?>{
        'user_answer': submission.userAnswer,
        'correct_answer': submission.correctAnswer,
        'error_type': submission.errorType?.wire,
        'question_type': submission.questionType?.wire,
        'skill': submission.skill.wire,
        'difficulty': submission.difficulty,
        'wrong_count': previous + 1,
        'last_wrong_at': stamp,
        'mastery': evolve.mastery,
        'updated_at': stamp,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return _MistakeOutcome(mistakeId: id, mastery: evolve.mastery);
  }

  // --- step 4: vocabulary memory ------------------------------------------

  Future<_MemoryOutcome> _applyMemory(
    Transaction txn,
    AnswerSubmission submission,
    DateTime now,
    String stamp,
  ) async {
    if (submission.refType != RefType.vocabulary) {
      return const _MemoryOutcome();
    }
    final String userId = submission.userId;

    final List<Map<String, Object?>> rows = await txn.query(
      'vocabulary_reviews',
      where: 'user_id = ? AND vocabulary_id = ?',
      whereArgs: <Object?>[userId, submission.refId],
      limit: 1,
    );

    final VocabularyReview current = rows.isEmpty
        ? VocabularyReview(userId: userId, vocabularyId: submission.refId)
        : VocabularyReview.fromMap(rows.first);

    final VocabularyReview updated =
        _memory.applyResult(current, correct: submission.isCorrect);
    final bool mastered = updated.memoryLevel >= masteredMemoryLevel;
    final bool becameMastered = mastered && !current.isMastered;

    final Map<String, Object?> map = updated
        .copyWith(isMastered: mastered, updatedAt: now)
        .toMap()
      ..remove('id');

    if (rows.isEmpty) {
      await txn.insert('vocabulary_reviews', map);
    } else {
      await txn.update(
        'vocabulary_reviews',
        map,
        where: 'id = ?',
        whereArgs: <Object?>[rows.first['id']],
      );
    }

    return _MemoryOutcome(
      memoryLevel: updated.memoryLevel,
      becameMastered: becameMastered,
    );
  }

  // --- step 5 + 6: skill score & difficulty -------------------------------

  Future<_SkillOutcome> _applySkill(
    Transaction txn,
    AnswerSubmission submission,
    DateTime now,
    String stamp,
  ) async {
    final String userId = submission.userId;
    final SkillType skill = submission.skill;

    final List<AnswerSample> samples =
        await _samplesFor(txn, userId, skill, limit: skillScoreWindow);

    final List<Map<String, Object?>> scoreRows = await txn.query(
      'skill_scores',
      where: 'user_id = ? AND skill = ?',
      whereArgs: <Object?>[userId, skill.wire],
      limit: 1,
    );

    final double previousScore = scoreRows.isEmpty
        ? fallbackPreviousScore
        : doubleOrDefault(scoreRows.first['score'], fallbackPreviousScore);
    final int previousDifficulty = scoreRows.isEmpty
        ? 2
        : intOrDefault(scoreRows.first['current_difficulty'], 2);
    final int previousSampleCount =
        scoreRows.isEmpty ? 0 : intOrDefault(scoreRows.first['sample_count'], 0);

    final double newScore =
        _skillScore.score(samples: samples, previousScore: previousScore);

    final List<AnswerSample> orderedWindow = _oldestFirst(samples);
    final List<AnswerSample> windowSamples =
        orderedWindow.length <= difficultyWindow
            ? orderedWindow
            : orderedWindow.sublist(orderedWindow.length - difficultyWindow);

    final DifficultyDecision decision = _difficulty.evaluate(
      window: windowSamples,
      currentDifficulty: previousDifficulty,
    );

    final SkillScore updated = SkillScore(
      id: scoreRows.isEmpty ? null : asInt(scoreRows.first['id']),
      userId: userId,
      skill: skill,
      score: newScore,
      currentDifficulty: decision.newDifficulty,
      sampleCount: previousSampleCount + 1,
      lastPracticedAt: now,
      updatedAt: now,
    );

    final Map<String, Object?> map = updated.toMap()..remove('id');
    if (scoreRows.isEmpty) {
      await txn.insert('skill_scores', map);
    } else {
      await txn.update(
        'skill_scores',
        map,
        where: 'id = ?',
        whereArgs: <Object?>[scoreRows.first['id']],
      );
    }

    return _SkillOutcome(
      score: newScore,
      difficulty: decision.newDifficulty,
      action: decision.action,
    );
  }

  // --- step 7: priority ---------------------------------------------------

  Future<double> _computePriority(
    Transaction txn,
    AnswerSubmission submission,
    DateTime now,
  ) async {
    final String userId = submission.userId;
    final SkillType skill = submission.skill;

    final List<Map<String, Object?>> goalRows = await txn.query(
      'study_goal',
      columns: <String>['target_band'],
      where: 'user_id = ? AND is_active = 1',
      whereArgs: <Object?>[userId],
      orderBy: 'id DESC',
      limit: 1,
    );
    final double targetBand =
        goalRows.isEmpty ? 7.0 : doubleOrDefault(goalRows.first['target_band'], 7.0);
    final double targetScore = (targetBand.clamp(0.0, 9.0).toDouble()) / 9.0 * 100.0;

    final String since = AppDateUtils.toUtcIso(
      now.subtract(const Duration(days: errorWindowDays)),
    );
    final List<Map<String, Object?>> errorRows = await txn.rawQuery(
      'SELECT COUNT(*) AS c, MAX(answered_at) AS m, AVG(difficulty) AS d '
      'FROM user_answers WHERE user_id = ? AND skill = ? AND is_correct = 0 '
      'AND answered_at >= ?',
      <Object?>[userId, skill.wire, since],
    );

    final int errorCount = errorRows.isEmpty ? 0 : intOrDefault(errorRows.first['c'], 0);
    if (errorCount == 0) {
      return 1.0;
    }
    final String? lastAt = errorRows.first['m'] as String?;
    final DateTime lastError =
        AppDateUtils.parseUtcIso(lastAt) ?? now;
    final double daysSince =
        now.difference(lastError).inMinutes.toDouble() / 1440.0;
    final double avgDifficulty =
        errorRows.first['d'] == null ? 3.0 : doubleOrDefault(errorRows.first['d'], 3.0);

    final List<Map<String, Object?>> scoreRows = await txn.query(
      'skill_scores',
      columns: <String>['score'],
      where: 'user_id = ? AND skill = ?',
      whereArgs: <Object?>[userId, skill.wire],
      limit: 1,
    );
    final double currentScore = scoreRows.isEmpty
        ? fallbackPreviousScore
        : doubleOrDefault(scoreRows.first['score'], fallbackPreviousScore);

    return _priority
        .evaluate(
          PriorityCandidate(
            key: skill.wire,
            errorCount: errorCount,
            targetScore: targetScore,
            currentScore: currentScore,
            daysSinceLastError: daysSince < 0 ? 0 : daysSince,
            averageDifficulty: avgDifficulty,
          ),
        )
        .priority;
  }

  // --- step 8: statistics + streak ----------------------------------------

  Future<int> _applyStatistics(
    Transaction txn,
    AnswerSubmission submission,
    _MemoryOutcome memory,
    String today,
    DateTime now,
    String stamp,
  ) async {
    final String userId = submission.userId;
    final bool isVocab = submission.refType == RefType.vocabulary;
    final int addedMinutes = submission.timeSpentMs <= 0
        ? 0
        : (submission.timeSpentMs / 60000).round();

    final List<Map<String, Object?>> todayRows = await txn.query(
      'learning_statistics',
      where: 'user_id = ? AND stat_date = ?',
      whereArgs: <Object?>[userId, today],
      limit: 1,
    );

    final List<Map<String, Object?>> prevRows = await txn.query(
      'learning_statistics',
      where: 'user_id = ? AND stat_date < ?',
      whereArgs: <Object?>[userId, today],
      orderBy: 'stat_date DESC',
      limit: 1,
    );

    final int prevLifetimeMinutes =
        prevRows.isEmpty ? 0 : intOrDefault(prevRows.first['total_study_minutes'], 0);
    final int prevTotalDays =
        prevRows.isEmpty ? 0 : intOrDefault(prevRows.first['total_days'], 0);

    final bool isNewDay = todayRows.isEmpty;
    final int baseStudyMinutes =
        isNewDay ? 0 : intOrDefault(todayRows.first['study_minutes'], 0);
    final int baseAnswered =
        isNewDay ? 0 : intOrDefault(todayRows.first['questions_answered'], 0);
    final int baseCorrect =
        isNewDay ? 0 : intOrDefault(todayRows.first['correct_count'], 0);
    final int baseWordsReviewed =
        isNewDay ? 0 : intOrDefault(todayRows.first['words_reviewed'], 0);
    final int baseWordsMastered =
        isNewDay ? 0 : intOrDefault(todayRows.first['words_mastered'], 0);
    // Streak and `last_study_date` are running totals, not per-day figures:
    // when today has no row yet, continue from the most recent previous day so
    // consecutive days actually increment instead of restarting at 1.
    final int baseStreak = isNewDay
        ? (prevRows.isEmpty
            ? 0
            : intOrDefault(prevRows.first['current_streak'], 0))
        : intOrDefault(todayRows.first['current_streak'], 0);
    final String? baseLastStudyDate = isNewDay
        ? (prevRows.isEmpty ? null : asString(prevRows.first['last_study_date']))
        : asString(todayRows.first['last_study_date']);
    final int baseLifetimeMinutes = isNewDay
        ? prevLifetimeMinutes
        : intOrDefault(todayRows.first['total_study_minutes'], 0);

    final StreakResult streakResult = _streak.onStudyEvent(
      lastStudyDate: baseLastStudyDate,
      currentStreak: baseStreak,
    );
    final int newStreak =
        streakResult.changed ? streakResult.streak : baseStreak;
    final String newLastStudyDate = streakResult.changed
        ? streakResult.lastStudyDate
        : (baseLastStudyDate ?? today);

    final int newStudyMinutes = baseStudyMinutes + addedMinutes;
    // `total_days` is also a running total: a new day adds one, but on a repeat
    // answer the same day must keep today's already-counted value (reading it
    // from the previous day would reset it).
    final int newTotalDays = isNewDay
        ? prevTotalDays + 1
        : intOrDefault(todayRows.first['total_days'], prevTotalDays);

    final Map<String, Object?> row = <String, Object?>{
      'user_id': userId,
      'stat_date': today,
      'study_minutes': newStudyMinutes,
      'questions_answered': baseAnswered + 1,
      'correct_count': baseCorrect + (submission.isCorrect ? 1 : 0),
      'words_reviewed': baseWordsReviewed + (isVocab ? 1 : 0),
      'words_mastered': baseWordsMastered + (memory.becameMastered ? 1 : 0),
      'current_streak': newStreak,
      'last_study_date': newLastStudyDate,
      'total_study_minutes': baseLifetimeMinutes + addedMinutes,
      'total_days': newTotalDays,
      'updated_at': stamp,
    };

    if (isNewDay) {
      await txn.insert('learning_statistics', row);
    } else {
      await txn.update(
        'learning_statistics',
        row,
        where: 'id = ?',
        whereArgs: <Object?>[todayRows.first['id']],
      );
    }
    return newStreak;
  }

  // --- step 9: daily task -------------------------------------------------

  Future<int?> _applyDailyTask(
    Transaction txn,
    AnswerSubmission submission,
    String today,
    String stamp,
    double priority,
  ) async {
    final String userId = submission.userId;
    final List<Map<String, Object?>> tasks = await txn.query(
      'daily_tasks',
      where: 'user_id = ? AND plan_date = ?',
      whereArgs: <Object?>[userId, today],
      orderBy: 'sort_order ASC, id ASC',
    );
    if (tasks.isEmpty) {
      return null;
    }

    Map<String, Object?>? target;
    for (final Map<String, Object?> task in tasks) {
      if (_taskMatches(task, submission)) {
        target = task;
        break;
      }
    }
    target ??= tasks.first;

    final int id = intOrDefault(target['id'], 0);
    final int itemCount = intOrDefault(target['item_count'], 0);
    final int completed = intOrDefault(target['completed_count'], 0) + 1;
    final int capped = itemCount > 0 && completed > itemCount ? itemCount : completed;
    final bool done = itemCount > 0 && capped >= itemCount;
    final TaskStatus status = done ? TaskStatus.done : TaskStatus.inProgress;

    final Map<String, Object?> payload =
        decodeMap(target['payload']) ?? <String, Object?>{};
    payload['priority'] = priority;

    await txn.update(
      'daily_tasks',
      <String, Object?>{
        'completed_count': capped,
        'status': status.wire,
        'payload': encodeMap(payload),
        'updated_at': stamp,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    return id;
  }

  bool _taskMatches(Map<String, Object?> task, AnswerSubmission submission) {
    final TaskType? type = TaskType.maybeFromWire(asString(task['task_type']));
    final SkillType? skill = SkillType.maybeFromWire(asString(task['skill']));

    if (submission.isRedo) {
      return type == TaskType.mistakeReview;
    }
    switch (submission.refType) {
      case RefType.vocabulary:
        return skill == SkillType.vocabulary ||
            type == TaskType.vocabReview ||
            type == TaskType.vocabPractice;
      case RefType.reading:
        return skill == SkillType.reading || type == TaskType.reading;
    }
  }

  // --- helpers ------------------------------------------------------------

  /// Reads the most recent [limit] answers for [skill] as [AnswerSample]s.
  Future<List<AnswerSample>> _samplesFor(
    Transaction txn,
    String userId,
    SkillType skill, {
    required int limit,
  }) async {
    final List<Map<String, Object?>> rows = await txn.query(
      'user_answers',
      columns: <String>['is_correct', 'difficulty', 'answered_at', 'skill'],
      where: 'user_id = ? AND skill = ?',
      whereArgs: <Object?>[userId, skill.wire],
      orderBy: 'answered_at DESC, id DESC',
      limit: limit,
    );
    return rows
        .map(
          (Map<String, Object?> row) => AnswerSample(
            isCorrect: asBool(row['is_correct']),
            difficulty: intOrDefault(row['difficulty'], 3),
            answeredAt:
                AppDateUtils.parseUtcIso(asString(row['answered_at'])) ?? _clock.now(),
            skill: SkillType.maybeFromWire(asString(row['skill'])),
          ),
        )
        .toList(growable: false);
  }

  /// Returns [samples] ordered oldest → newest (stable by construction time).
  List<AnswerSample> _oldestFirst(List<AnswerSample> samples) {
    final List<AnswerSample> copy = List<AnswerSample>.of(samples)
      ..sort(
        (AnswerSample a, AnswerSample b) =>
            a.answeredAt.compareTo(b.answeredAt),
      );
    return copy;
  }
}

/// Internal: the mistake effects of one answer.
class _MistakeOutcome {
  const _MistakeOutcome({this.mistakeId, this.mastery, this.justMastered = false});

  final int? mistakeId;
  final double? mastery;
  final bool justMastered;
}

/// Internal: the vocabulary-memory effects of one answer.
class _MemoryOutcome {
  const _MemoryOutcome({this.memoryLevel, this.becameMastered = false});

  final int? memoryLevel;
  final bool becameMastered;
}

/// Internal: the skill effects of one answer.
class _SkillOutcome {
  const _SkillOutcome({this.score, this.difficulty, this.action});

  final double? score;
  final int? difficulty;
  final DifficultyAction? action;
}
