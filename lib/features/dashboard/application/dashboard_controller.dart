/// Dashboard aggregate (PRD §4.2 / BRIEF §5).
///
/// Answers "what should I study today?" by combining the study goal, today's
/// persisted tasks, the five-dimension ability scores and the study streak into
/// one immutable snapshot. Everything is read lazily with indexed, bounded
/// queries (ARCHITECTURE §9.4, NFR-11): no full-table scans.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/models/daily_task.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/learning_statistics.dart';
import 'package:ielts_free/core/models/study_goal.dart';
import 'package:ielts_free/core/providers/refresh_provider.dart';
import 'package:ielts_free/core/providers/repository_providers.dart';
import 'package:ielts_free/core/providers/service_providers.dart';
import 'package:ielts_free/core/services/adaptive/phase_service.dart';
import 'package:ielts_free/core/storage/repositories/plan_repository.dart';
import 'package:ielts_free/core/storage/repositories/progress_repository.dart';
import 'package:ielts_free/core/storage/repositories/study_goal_repository.dart';
import 'package:ielts_free/core/utils/logger.dart';
import 'package:ielts_free/features/study_plan/application/study_plan_generator.dart';

/// Immutable Dashboard snapshot.
@immutable
class DashboardData {
  const DashboardData({
    this.targetBand = AppConstants.defaultTargetBand,
    this.examDate,
    this.daysRemaining,
    this.todayProgress = 0.0,
    this.todayTasks = const <DailyTask>[],
    this.skillScores = const <SkillType, int>{},
    this.streak = 0,
    this.todayMinutes = 0,
  });

  /// Target band (e.g. `7.0`).
  final double targetBand;

  /// Exam date (`YYYY-MM-DD`), or `null`.
  final String? examDate;

  /// Days until the exam, or `null`.
  final int? daysRemaining;

  /// Today's completion ratio in `[0, 1]`.
  final double todayProgress;

  /// Today's tasks.
  final List<DailyTask> todayTasks;

  /// Five-dimension scores as integers in `[0, 100]` (PRD Q-4).
  final Map<SkillType, int> skillScores;

  /// Current study streak (days).
  final int streak;

  /// Minutes studied today.
  final int todayMinutes;

  /// Whether today's plan has any tasks.
  bool get hasPlan => todayTasks.isNotEmpty;

  /// Score for [skill] (`0` when unknown).
  int scoreOf(SkillType skill) => skillScores[skill] ?? 0;
}

/// Controller that aggregates the Dashboard.
class DashboardController extends AsyncNotifier<DashboardData> {
  @override
  Future<DashboardData> build() {
    ref.watch(dataRevisionProvider);
    return _load();
  }

  /// Generates today's plan (if the user has none yet) and refreshes.
  Future<void> generateTodayPlan() async {
    try {
      final StudyPlanGenerator generator =
          await ref.read(studyPlanGeneratorProvider.future);
      await generator.generateForDate(AppConstants.localUserId);
      state = AsyncData<DashboardData>(await _load());
      notifyDataChanged(ref);
    } on Object catch (error, stackTrace) {
      appLogger.warning('Dashboard plan generation failed.', error, stackTrace);
      rethrow;
    }
  }

  // --- internals ----------------------------------------------------------

  Future<DashboardData> _load() async {
    const String userId = AppConstants.localUserId;

    final StudyGoalRepository goalRepository =
        await ref.read(studyGoalRepositoryProvider.future);
    final StudyGoal goal = await goalRepository.ensureDefault(userId: userId);

    final PhaseService phaseService = ref.read(phaseServiceProvider);
    final int? daysRemaining = phaseService.daysRemainingFor(goal.examDate);

    final PlanRepository planRepository =
        await ref.read(planRepositoryProvider.future);
    final List<DailyTask> tasks =
        await planRepository.tasksForDate(userId);

    final ProgressRepository progressRepository =
        await ref.read(progressRepositoryProvider.future);
    final Map<SkillType, double> rawScores =
        await progressRepository.skillScoreMap(userId);
    final LearningStatistics? stats =
        await progressRepository.todayStatistics(userId);

    return DashboardData(
      targetBand: goal.targetBand,
      examDate: goal.examDate,
      daysRemaining: daysRemaining,
      todayProgress: _averageProgress(tasks),
      todayTasks: tasks,
      skillScores: _roundedScores(rawScores),
      streak: stats?.currentStreak ?? 0,
      todayMinutes: stats?.studyMinutes ?? 0,
    );
  }

  double _averageProgress(List<DailyTask> tasks) {
    if (tasks.isEmpty) {
      return 0.0;
    }
    double sum = 0;
    for (final DailyTask task in tasks) {
      sum += task.progress;
    }
    return (sum / tasks.length).clamp(0.0, 1.0).toDouble();
  }

  Map<SkillType, int> _roundedScores(Map<SkillType, double> scores) {
    final Map<SkillType, int> result = <SkillType, int>{};
    for (final SkillType skill in SkillType.fiveDimensions) {
      final double value = scores[skill] ?? 0.0;
      result[skill] = value.round().clamp(0, 100).toInt();
    }
    return result;
  }
}

/// Provider for the Dashboard controller.
final AsyncNotifierProvider<DashboardController, DashboardData>
    dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardData>(
  DashboardController.new,
);
