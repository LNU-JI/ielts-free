/// Closed-loop integration test — FR-064 / BRIEF §94 / PRD G-2.
///
/// Proves the whole learning loop on a real (in-memory) SQLite database through
/// the real [SubmitAnswerUseCase]:
///
///   answer → user_answers → mistakes → skill_scores → difficulty/priority →
///   daily_tasks change → statistics + streak
///
/// Nothing on the critical path is mocked: the transaction, the DAO-level SQL and
/// the adaptive services all run for real.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/models/enums/error_type.dart';
import 'package:ielts_free/core/models/enums/ref_type.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/enums/task_status.dart';
import 'package:ielts_free/core/models/enums/task_type.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/services/adaptive/adaptive_models.dart';
import 'package:ielts_free/core/services/adaptive/daily_plan_service.dart';
import 'package:ielts_free/core/services/adaptive/difficulty_service.dart';
import 'package:ielts_free/core/services/adaptive/mastery_service.dart';
import 'package:ielts_free/core/services/adaptive/memory_service.dart';
import 'package:ielts_free/core/services/adaptive/priority_service.dart';
import 'package:ielts_free/core/services/adaptive/skill_score_service.dart';
import 'package:ielts_free/core/services/adaptive/streak_service.dart';
import 'package:ielts_free/core/services/clock_service.dart';
import 'package:ielts_free/core/services/grading_service.dart';
import 'package:ielts_free/core/services/submit_answer_usecase.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

import '../helpers/test_database.dart';

void main() {
  setUpAll(initTestDatabaseFactory);

  const String userId = 'local_user';
  final DateTime now = DateTime.utc(2026, 6, 15, 12);
  final FixedClock clock = FixedClock(now);
  final String today = AppDateUtils.localDateString(now);

  late Database db;
  late SubmitAnswerUseCase useCase;

  setUp(() async {
    db = await openInMemoryUserDb(version: 1);

    // Anchor user + goal + today's plan.
    await db.insert('users', <String, Object?>{
      'id': userId,
      'created_at': AppDateUtils.toUtcIso(now),
    });
    await db.insert('study_goal', <String, Object?>{
      'user_id': userId,
      'target_band': 7.0,
      'exam_date': '2026-08-01',
      'daily_study_minutes': 60,
      'plan_type': 'DAY90',
      'is_active': 1,
    });
    await db.insert('daily_tasks', <String, Object?>{
      'user_id': userId,
      'plan_date': today,
      'task_type': TaskType.vocabReview.wire,
      'skill': SkillType.vocabulary.wire,
      'title': '词汇复习',
      'target_minutes': 15,
      'item_count': 10,
      'completed_count': 0,
      'status': TaskStatus.pending.wire,
      'sort_order': 0,
      'payload': '{}',
    });

    useCase = SubmitAnswerUseCase(
      db: db,
      gradingService: const GradingService(),
      memoryService: MemoryService(clock: clock),
      skillScoreService: SkillScoreService(clock: clock),
      difficultyService: const DifficultyService(),
      priorityService: const PriorityService(),
      masteryService: const MasteryService(),
      streakService: StreakService(clock: clock),
      clock: clock,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> count(String table) async =>
      Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table')) ??
      0;

  Future<Map<String, Object?>> todayTask() async {
    final List<Map<String, Object?>> rows = await db.query(
      'daily_tasks',
      where: 'user_id = ? AND plan_date = ?',
      whereArgs: <Object?>[userId, today],
    );
    return rows.first;
  }

  test('a wrong answer creates a classified mistake and bumps progress',
      () async {
    await useCase.submitVocabulary(
      userId: userId,
      vocabularyId: 1,
      kind: VocabQuestionKind.spelling,
      expected: 'mitigate',
      actual: 'zzzz',
      difficulty: 3,
      timeSpentMs: 60000,
    );

    // user_answers recorded
    expect(await count('user_answers'), 1);
    // mistake created with the right taxonomy
    final List<Map<String, Object?>> mistakes = await db.query('mistakes');
    expect(mistakes, hasLength(1));
    expect(mistakes.first['ref_type'], RefType.vocabulary.wire);
    expect(mistakes.first['ref_id'], 1);
    expect(mistakes.first['wrong_count'], 1);
    expect(mistakes.first['error_type'], ErrorType.spelling.wire);
    // memory level dropped (already at floor 0)
    final List<Map<String, Object?>> reviews =
        await db.query('vocabulary_reviews');
    expect(reviews, hasLength(1));
    expect(reviews.first['memory_level'], 0);
    expect(reviews.first['wrong_count'], 1);
  });

  test('repeated wrong answers bump wrong_count instead of duplicating',
      () async {
    for (int i = 0; i < 3; i++) {
      await useCase.submitVocabulary(
        userId: userId,
        vocabularyId: 1,
        kind: VocabQuestionKind.spelling,
        expected: 'mitigate',
        actual: 'zzzz',
      );
    }
    final List<Map<String, Object?>> mistakes = await db.query('mistakes');
    expect(mistakes, hasLength(1));
    expect(mistakes.first['wrong_count'], 3);
  });

  test('the full loop: wrong batch → skill score / task / stats change → '
      'correct redo → mastery up', () async {
    // --- capture the "before" state -------------------------------------
    final Map<String, Object?> taskBefore = await todayTask();
    final Map<String, Object?> payloadBefore =
        decodeMap(taskBefore['payload']) ?? <String, Object?>{};
    expect(payloadBefore.containsKey('priority'), isFalse);

    // --- a batch of WRONG answers (3 different words) -------------------
    for (final int id in <int>[1, 2, 3]) {
      await useCase.submitVocabulary(
        userId: userId,
        vocabularyId: id,
        kind: VocabQuestionKind.spelling,
        expected: 'mitigate',
        actual: 'zzzz',
        difficulty: 3,
        timeSpentMs: 30000,
      );
    }

    expect(await count('mistakes'), 3);
    expect(await count('user_answers'), 3);

    // --- skill score changed (no longer the 40.0 fallback) --------------
    final List<Map<String, Object?>> scores = await db.query(
      'skill_scores',
      where: 'user_id = ? AND skill = ?',
      whereArgs: <Object?>[userId, SkillType.vocabulary.wire],
    );
    expect(scores, hasLength(1));
    final double newScore = (scores.first['score']! as num).toDouble();
    expect(newScore, isNot(SubmitAnswerUseCase.fallbackPreviousScore));
    expect(newScore, inInclusiveRange(0, 100));
    expect(scores.first['sample_count'], 3);

    // --- daily task advanced + payload now carries a priority ----------
    final Map<String, Object?> taskAfter = await todayTask();
    expect(taskAfter['completed_count'], 3);
    expect(taskAfter['status'], TaskStatus.inProgress.wire);
    final Map<String, Object?> payloadAfter =
        decodeMap(taskAfter['payload']) ?? <String, Object?>{};
    expect(payloadAfter.containsKey('priority'), isTrue);
    final double priority = (payloadAfter['priority']! as num).toDouble();
    expect(priority, greaterThan(1.0));

    // --- statistics + streak -------------------------------------------
    final List<Map<String, Object?>> stats = await db.query('learning_statistics');
    expect(stats, hasLength(1));
    expect(stats.first['questions_answered'], 3);
    expect(stats.first['correct_count'], 0);
    expect(stats.first['words_reviewed'], 3);
    expect(stats.first['current_streak'], 1);
    expect(stats.first['last_study_date'], today);

    // --- the NEXT training differs: re-plan with the new signals --------
    const DailyPlanService planSvc = DailyPlanService();
    List<DailyPlanItem> plan(Map<SkillType, double> s, Map<SkillType, double> p) =>
        planSvc.buildPlan(
          DailyPlanInput(
            targetBand: 7.0,
            skillScores: s,
            daysRemaining: 60,
            dailyMinutes: 60,
            priorities: p,
          ),
        );
    final List<DailyPlanItem> planBefore = plan(
      <SkillType, double>{SkillType.vocabulary: 40},
      <SkillType, double>{SkillType.vocabulary: 1.0},
    );
    final List<DailyPlanItem> planAfter = plan(
      <SkillType, double>{SkillType.vocabulary: newScore},
      <SkillType, double>{SkillType.vocabulary: priority},
    );
    double vocabPriority(List<DailyPlanItem> items) => items
        .firstWhere((DailyPlanItem i) => i.bucket == DailyPlanBucket.vocabulary)
        .priority;
    expect(vocabPriority(planAfter), isNot(vocabPriority(planBefore)));

    // --- a CORRECT redo raises mastery ----------------------------------
    final List<Map<String, Object?>> mistakeRows = await db.query(
      'mistakes',
      where: 'ref_id = ?',
      whereArgs: <Object?>[1],
    );
    final int mistakeId = mistakeRows.first['id']! as int;
    final SubmitAnswerResult redo = await useCase.submitVocabulary(
      userId: userId,
      vocabularyId: 1,
      kind: VocabQuestionKind.spelling,
      expected: 'mitigate',
      actual: 'mitigate',
      isRedo: true,
      mistakeId: mistakeId,
    );
    expect(redo.isCorrect, isTrue);
    expect(redo.mastery, greaterThan(0.0));

    final List<Map<String, Object?>> redoRow = await db.query(
      'mistakes',
      where: 'id = ?',
      whereArgs: <Object?>[mistakeId],
    );
    expect(redoRow.first['mastery'], greaterThan(0.0));
    // the redo is a correct answer → counts toward today's correct tally
    final List<Map<String, Object?>> statsAfter =
        await db.query('learning_statistics');
    expect(statsAfter.first['questions_answered'], 4);
    expect(statsAfter.first['correct_count'], 1);
  });

  test('a correct vocabulary answer raises the memory level to L1', () async {
    final SubmitAnswerResult r = await useCase.submitVocabulary(
      userId: userId,
      vocabularyId: 9,
      kind: VocabQuestionKind.spelling,
      expected: 'mitigate',
      actual: 'mitigate',
    );
    expect(r.isCorrect, isTrue);
    expect(r.memoryLevel, 1);
    expect(await count('mistakes'), 0);
  });

  test('a reading answer records the reading skill and its mistake', () async {
    final SubmitAnswerResult r = await useCase.submit(
      const AnswerSubmission(
        userId: userId,
        refType: RefType.reading,
        refId: 101,
        skill: SkillType.readingTfng,
        userAnswer: 'FALSE',
        correctAnswer: 'NOT GIVEN',
        isCorrect: false,
        errorType: ErrorType.readingParaphrase,
      ),
    );
    expect(r.isCorrect, isFalse);
    final List<Map<String, Object?>> mistakes = await db.query('mistakes');
    expect(mistakes.first['ref_type'], RefType.reading.wire);
    expect(mistakes.first['skill'], SkillType.readingTfng.wire);
    final List<Map<String, Object?>> scores = await db.query(
      'skill_scores',
      where: 'skill = ?',
      whereArgs: <Object?>[SkillType.readingTfng.wire],
    );
    expect(scores, hasLength(1));
  });

  test('the whole loop is atomic: a failing statement leaves no partial rows',
      () async {
    // Force a failure by referencing a vocabulary id that violates nothing but
    // by passing an out-of-range difficulty so a CHECK on a derived table fires.
    // Simpler: drop a table the transaction touches to force an error.
    await db.execute('DROP TABLE learning_statistics');
    await expectLater(
      useCase.submitVocabulary(
        userId: userId,
        vocabularyId: 1,
        kind: VocabQuestionKind.spelling,
        expected: 'mitigate',
        actual: 'zzzz',
      ),
      throwsA(anything),
    );
    // The transaction rolled back → no answer, no mistake.
    expect(await count('user_answers'), 0);
    expect(await count('mistakes'), 0);
  });
}
