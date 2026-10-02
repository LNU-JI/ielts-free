/// Builds a day's task plan from the adaptive engine and persists it.
///
/// This is the bridge between the pure §5.5 algorithm and the `daily_tasks`
/// table: it gathers the inputs (goal, profile, skill scores, mistake-driven
/// priorities), asks [DailyPlanService] for the buckets, maps them through
/// [DailyPlanMapper] and writes the result atomically.
///
/// It is shared by the Dashboard ("生成今日任务") and the Study Plan page so the
/// two screens can never disagree about what today's plan is.
library;

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/core/models/daily_task.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/study_goal.dart';
import 'package:ielts_free/core/models/user_answer.dart';
import 'package:ielts_free/core/models/user_profile.dart';
import 'package:ielts_free/core/providers/repository_providers.dart';
import 'package:ielts_free/core/providers/service_providers.dart';
import 'package:ielts_free/core/services/adaptive/adaptive_models.dart';
import 'package:ielts_free/core/services/adaptive/daily_plan_service.dart';
import 'package:ielts_free/core/services/adaptive/phase_service.dart';
import 'package:ielts_free/core/services/adaptive/priority_service.dart';
import 'package:ielts_free/core/services/clock_service.dart';
import 'package:ielts_free/core/storage/repositories/plan_repository.dart';
import 'package:ielts_free/core/storage/repositories/progress_repository.dart';
import 'package:ielts_free/core/storage/repositories/study_goal_repository.dart';
import 'package:ielts_free/core/storage/repositories/user_profile_repository.dart';
import 'package:ielts_free/core/utils/date_utils.dart';
import 'package:ielts_free/features/study_plan/application/daily_plan_mapper.dart';

/// Generates and persists daily task plans.
class StudyPlanGenerator {
  const StudyPlanGenerator({
    required DailyPlanService dailyPlanService,
    required PhaseService phaseService,
    required PriorityService priorityService,
    required PlanRepository planRepository,
    required ProgressRepository progressRepository,
    required StudyGoalRepository goalRepository,
    required UserProfileRepository profileRepository,
    required Clock clock,
    DailyPlanMapper mapper = const DailyPlanMapper(),
  })  : _dailyPlan = dailyPlanService,
        _phase = phaseService,
        _priority = priorityService,
        _plans = planRepository,
        _progress = progressRepository,
        _goals = goalRepository,
        _profiles = profileRepository,
        _clock = clock,
        _mapper = mapper;

  final DailyPlanService _dailyPlan;
  final PhaseService _phase;
  final PriorityService _priority;
  final PlanRepository _plans;
  final ProgressRepository _progress;
  final StudyGoalRepository _goals;
  final UserProfileRepository _profiles;
  final Clock _clock;
  final DailyPlanMapper _mapper;

  /// Window (days) of wrong answers folded into the priority factors (§5.3).
  static const int errorWindowDays = 14;

  /// Builds the engine items for [userId] **without** persisting anything.
  ///
  /// Used for the weekly preview on the Study Plan page.
  Future<List<DailyPlanItem>> buildItems(String userId) async {
    final StudyGoal goal = await _goals.ensureDefault(userId: userId);
    final UserProfile profile = await _profiles.ensureDefault(userId: userId);
    final Map<SkillType, double> scores =
        await _progress.skillScoreMap(userId);
    final int? daysRemaining = _phase.daysRemainingFor(goal.examDate);
    final Map<SkillType, double> priorities =
        await _priorities(userId, goal.targetBand, scores);

    return _dailyPlan.buildPlan(
      DailyPlanInput(
        targetBand: goal.targetBand,
        skillScores: scores,
        daysRemaining: daysRemaining,
        dailyMinutes: goal.dailyStudyMinutes,
        priorities: priorities,
        weakestSkill: profile.weakestSkill,
      ),
    );
  }

  /// Generates today's (or [planDate]'s) tasks and stores them.
  ///
  /// Returns the persisted tasks (with ids) so callers can render immediately.
  Future<List<DailyTask>> generateForDate(
    String userId, {
    String? planDate,
  }) async {
    final DateTime now = _clock.now();
    final String date = planDate ?? AppDateUtils.localDateString(now);
    final List<DailyPlanItem> items = await buildItems(userId);
    final List<DailyTask> tasks = _mapper.toDailyTasks(
      items,
      planDate: date,
      userId: userId,
      now: now,
    );
    await _plans.replaceTasks(userId, date, tasks);
    return _plans.tasksForDate(userId, planDate: date);
  }

  // --- internals ----------------------------------------------------------

  Future<Map<SkillType, double>> _priorities(
    String userId,
    double targetBand,
    Map<SkillType, double> scores,
  ) async {
    final List<UserAnswer> answers =
        await _progress.recentAnswers(userId, limit: 200);
    if (answers.isEmpty) {
      return const <SkillType, double>{};
    }

    final DateTime now = _clock.now();
    final double targetScore =
        (targetBand.clamp(0.0, 9.0).toDouble()) / 9.0 * 100.0;

    final List<PriorityCandidate> candidates = <PriorityCandidate>[];
    for (final SkillType skill in SkillType.fiveDimensions) {
      int errors = 0;
      double difficultySum = 0;
      int difficultyCount = 0;
      double minAge = double.infinity;

      for (final UserAnswer answer in answers) {
        if (answer.skill != skill || answer.isCorrect) {
          continue;
        }
        final double age = _ageDays(now, answer.answeredAt);
        if (age > errorWindowDays) {
          continue;
        }
        errors++;
        final int difficulty = answer.difficulty ?? 3;
        difficultySum += difficulty;
        difficultyCount++;
        if (age < minAge) {
          minAge = age;
        }
      }

      if (errors == 0) {
        continue;
      }
      candidates.add(
        PriorityCandidate(
          key: skill.wire,
          errorCount: errors,
          targetScore: targetScore,
          currentScore: scores[skill] ?? 0.0,
          daysSinceLastError: minAge.isFinite ? minAge : errorWindowDays.toDouble(),
          averageDifficulty:
              difficultyCount == 0 ? 3.0 : difficultySum / difficultyCount,
        ),
      );
    }

    if (candidates.isEmpty) {
      return const <SkillType, double>{};
    }

    final Map<SkillType, double> result = <SkillType, double>{};
    for (final PriorityItem item in _priority.rank(candidates)) {
      final SkillType? skill = SkillType.maybeFromWire(item.key);
      if (skill != null) {
        result[skill] = item.priority;
      }
    }
    return result;
  }

  double _ageDays(DateTime now, DateTime answeredAt) {
    final double minutes =
        now.difference(answeredAt.toUtc()).inMinutes.toDouble();
    return math.max(0.0, minutes) / 1440.0;
  }
}

/// Provider for the shared [StudyPlanGenerator].
final FutureProvider<StudyPlanGenerator> studyPlanGeneratorProvider =
    FutureProvider<StudyPlanGenerator>((Ref ref) async {
  return StudyPlanGenerator(
    dailyPlanService: ref.watch(dailyPlanServiceProvider),
    phaseService: ref.watch(phaseServiceProvider),
    priorityService: ref.watch(priorityServiceProvider),
    planRepository: await ref.watch(planRepositoryProvider.future),
    progressRepository: await ref.watch(progressRepositoryProvider.future),
    goalRepository: await ref.watch(studyGoalRepositoryProvider.future),
    profileRepository: await ref.watch(userProfileRepositoryProvider.future),
    clock: ref.watch(clockProvider),
  );
});
