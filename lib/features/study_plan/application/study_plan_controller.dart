/// Study Plan state (PRD §4.7).
///
/// Loads the active goal (period + phase), the algorithm's preview for the next
/// seven days and today's persisted tasks. Changing the period or regenerating
/// today's plan writes through to `study_goal` / `daily_tasks` and invalidates
/// the Dashboard so the two screens stay in sync (ARCHITECTURE §9.3, FR-064).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/core/models/daily_task.dart';
import 'package:ielts_free/core/models/enums/plan_phase.dart';
import 'package:ielts_free/core/models/enums/plan_type.dart';
import 'package:ielts_free/core/models/enums/task_type.dart';
import 'package:ielts_free/core/models/study_goal.dart';
import 'package:ielts_free/core/providers/refresh_provider.dart';
import 'package:ielts_free/core/providers/repository_providers.dart';
import 'package:ielts_free/core/providers/service_providers.dart';
import 'package:ielts_free/core/services/adaptive/adaptive_models.dart';
import 'package:ielts_free/core/services/adaptive/phase_service.dart';
import 'package:ielts_free/core/storage/repositories/plan_repository.dart';
import 'package:ielts_free/core/storage/repositories/study_goal_repository.dart';
import 'package:ielts_free/core/utils/date_utils.dart';
import 'package:ielts_free/core/utils/logger.dart';
import 'package:ielts_free/features/study_plan/application/study_plan_generator.dart';

/// One row of the weekly schedule.
@immutable
class PlanDayPreview {
  const PlanDayPreview({
    required this.date,
    required this.weekdayLabel,
    required this.isToday,
    required this.summary,
  });

  /// Local `YYYY-MM-DD`.
  final String date;

  /// e.g. `周一`.
  final String weekdayLabel;

  /// Whether this row is today.
  final bool isToday;

  /// Compact summary such as `词汇 20 词 · 阅读 1 篇 · 错题 5 题`.
  final String summary;
}

/// Immutable Study Plan state.
@immutable
class StudyPlanState {
  const StudyPlanState({
    this.period = PlanType.day30,
    this.customDays = 30,
    this.phase = PlanPhase.foundation,
    this.daysRemaining,
    this.todayTasks = const <DailyTask>[],
    this.weekly = const <PlanDayPreview>[],
    this.busy = false,
    this.error,
  });

  /// Selected plan period.
  final PlanType period;

  /// Days used when [period] is [PlanType.custom].
  final int customDays;

  /// Current phase derived from the exam countdown (§5.6).
  final PlanPhase phase;

  /// Days left until the exam, or `null`.
  final int? daysRemaining;

  /// Today's persisted tasks.
  final List<DailyTask> todayTasks;

  /// Seven-day preview (today first).
  final List<PlanDayPreview> weekly;

  /// Whether a write is in flight.
  final bool busy;

  /// A user-facing error, or `null`.
  final String? error;

  /// Today's completion ratio in `[0, 1]`.
  double get todayProgress {
    if (todayTasks.isEmpty) {
      return 0.0;
    }
    double sum = 0;
    for (final DailyTask task in todayTasks) {
      sum += task.progress;
    }
    return (sum / todayTasks.length).clamp(0.0, 1.0).toDouble();
  }

  StudyPlanState copyWith({
    PlanType? period,
    int? customDays,
    PlanPhase? phase,
    int? daysRemaining,
    List<DailyTask>? todayTasks,
    List<PlanDayPreview>? weekly,
    bool? busy,
    String? error,
    bool clearError = false,
  }) {
    return StudyPlanState(
      period: period ?? this.period,
      customDays: customDays ?? this.customDays,
      phase: phase ?? this.phase,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      todayTasks: todayTasks ?? this.todayTasks,
      weekly: weekly ?? this.weekly,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for the Study Plan page.
class StudyPlanController extends AsyncNotifier<StudyPlanState> {
  @override
  Future<StudyPlanState> build() {
    // Recompute whenever any screen writes user data (goal, tasks, …).
    ref.watch(dataRevisionProvider);
    return _load();
  }

  /// Changes the plan period (and, for [PlanType.custom], its length).
  Future<void> setPeriod(PlanType period, {int? customDays}) async {
    final StudyPlanState previous =
        state.valueOrNull ?? const StudyPlanState();
    state = AsyncData<StudyPlanState>(previous.copyWith(busy: true, clearError: true));

    try {
      final int days = _resolveCustomDays(period, customDays, previous);
      final String today = AppDateUtils.todayLocalDateString();
      final StudyGoalRepository goalRepository =
          await ref.read(studyGoalRepositoryProvider.future);
      final StudyGoal goal =
          await goalRepository.ensureDefault(userId: AppConstants.localUserId);
      await goalRepository.saveActive(
        StudyGoal(
          userId: goal.userId,
          targetBand: goal.targetBand,
          examDate: goal.examDate,
          dailyStudyMinutes: goal.dailyStudyMinutes,
          planType: period,
          planStartDate: today,
          planEndDate: AppDateUtils.addDaysToLocalDate(today, days),
          isActive: true,
          createdAt: goal.createdAt,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      state = AsyncData<StudyPlanState>(await _load());
      notifyDataChanged(ref);
    } on Object catch (error, stackTrace) {
      appLogger.warning('Study plan period change failed.', error, stackTrace);
      state = AsyncData<StudyPlanState>(
        previous.copyWith(busy: false, error: AppStrings.settingsSaveFailed),
      );
    }
  }

  /// Re-runs the algorithm for today and persists the fresh tasks.
  Future<void> regenerateToday() async {
    final StudyPlanState previous =
        state.valueOrNull ?? const StudyPlanState();
    state = AsyncData<StudyPlanState>(previous.copyWith(busy: true, clearError: true));

    try {
      final StudyPlanGenerator generator =
          await ref.read(studyPlanGeneratorProvider.future);
      await generator.generateForDate(AppConstants.localUserId);
      state = AsyncData<StudyPlanState>(await _load());
      notifyDataChanged(ref);
    } on Object catch (error, stackTrace) {
      appLogger.warning('Study plan regeneration failed.', error, stackTrace);
      state = AsyncData<StudyPlanState>(
        previous.copyWith(busy: false, error: AppStrings.settingsSaveFailed),
      );
    }
  }

  // --- internals ----------------------------------------------------------

  Future<StudyPlanState> _load() async {
    const String userId = AppConstants.localUserId;
    final StudyGoalRepository goalRepository =
        await ref.read(studyGoalRepositoryProvider.future);
    final StudyGoal goal = await goalRepository.ensureDefault(userId: userId);

    final PhaseService phaseService = ref.read(phaseServiceProvider);
    final int? daysRemaining = phaseService.daysRemainingFor(goal.examDate);

    final StudyPlanGenerator generator =
        await ref.read(studyPlanGeneratorProvider.future);
    final List<DailyPlanItem> items = await generator.buildItems(userId);

    final PlanRepository plans = await ref.read(planRepositoryProvider.future);
    final List<DailyTask> todayTasks = await plans.tasksForDate(userId);

    return StudyPlanState(
      period: goal.planType ?? PlanType.day30,
      customDays: _customDaysFrom(goal),
      phase: phaseService.phaseOf(daysRemaining),
      daysRemaining: daysRemaining,
      todayTasks: todayTasks,
      weekly: _buildWeekly(items, todayTasks),
    );
  }

  int _resolveCustomDays(PlanType period, int? customDays, StudyPlanState previous) {
    if (period != PlanType.custom) {
      return period.days == 0 ? previous.customDays : period.days;
    }
    final int requested = customDays ?? previous.customDays;
    return requested.clamp(1, 365).toInt();
  }

  int _customDaysFrom(StudyGoal goal) {
    final String? start = goal.planStartDate;
    final String? end = goal.planEndDate;
    if (start == null || end == null) {
      return goal.planType == PlanType.custom ? 30 : (goal.planType?.days ?? 30);
    }
    final int diff = AppDateUtils.daysBetweenLocalDates(
      AppDateUtils.parseLocalDate(start),
      AppDateUtils.parseLocalDate(end),
    );
    return diff <= 0 ? 30 : diff;
  }

  List<PlanDayPreview> _buildWeekly(
    List<DailyPlanItem> items,
    List<DailyTask> todayTasks,
  ) {
    final String today = AppDateUtils.todayLocalDateString();
    final String itemSummary = _summaryOfItems(items);
    final String todaySummary =
        todayTasks.isEmpty ? itemSummary : _summaryOfTasks(todayTasks);

    final List<PlanDayPreview> week = <PlanDayPreview>[];
    for (int i = 0; i < 7; i++) {
      final String date = AppDateUtils.addDaysToLocalDate(today, i);
      final int weekday = AppDateUtils.parseLocalDate(date).weekday; // 1..7
      final int index = (weekday - 1).clamp(0, 6).toInt();
      week.add(
        PlanDayPreview(
          date: date,
          weekdayLabel: AppStrings.studyPlanWeekdayNames[index],
          isToday: i == 0,
          summary: i == 0 ? todaySummary : itemSummary,
        ),
      );
    }
    return List<PlanDayPreview>.unmodifiable(week);
  }

  String _summaryOfItems(List<DailyPlanItem> items) {
    if (items.isEmpty) {
      return AppStrings.studyPlanEmpty;
    }
    final List<String> parts = <String>[];
    for (final DailyPlanItem item in items) {
      parts.add('${_bucketLabel(item.bucket)} ${item.itemCount} ${_bucketUnit(item.bucket)}');
    }
    return parts.join(' · ');
  }

  String _summaryOfTasks(List<DailyTask> tasks) {
    if (tasks.isEmpty) {
      return AppStrings.studyPlanEmpty;
    }
    final List<String> parts = <String>[];
    for (final DailyTask task in tasks) {
      final int count = task.itemCount ?? 0;
      parts.add('${_taskLabel(task)} $count ${_taskUnit(task)}');
    }
    return parts.join(' · ');
  }

  String _bucketLabel(DailyPlanBucket bucket) {
    switch (bucket) {
      case DailyPlanBucket.vocabulary:
        return AppStrings.learnHubVocabulary;
      case DailyPlanBucket.reading:
        return AppStrings.learnHubReading;
      case DailyPlanBucket.mistakes:
        return AppStrings.mistakesTitle;
    }
  }

  String _bucketUnit(DailyPlanBucket bucket) {
    switch (bucket) {
      case DailyPlanBucket.vocabulary:
        return AppStrings.wordsUnit;
      case DailyPlanBucket.reading:
        return AppStrings.passagesUnit;
      case DailyPlanBucket.mistakes:
        return AppStrings.questionsUnit;
    }
  }

  String _taskLabel(DailyTask task) {
    switch (task.taskType) {
      case TaskType.vocabReview:
      case TaskType.vocabPractice:
        return AppStrings.learnHubVocabulary;
      case TaskType.reading:
        return AppStrings.learnHubReading;
      case TaskType.mistakeReview:
        return AppStrings.mistakesTitle;
      case null:
        return AppStrings.learnHubVocabulary;
    }
  }

  String _taskUnit(DailyTask task) {
    switch (task.taskType) {
      case TaskType.vocabReview:
      case TaskType.vocabPractice:
        return AppStrings.wordsUnit;
      case TaskType.reading:
        return AppStrings.passagesUnit;
      case TaskType.mistakeReview:
        return AppStrings.questionsUnit;
      case null:
        return AppStrings.questionsUnit;
    }
  }
}

/// Provider for the Study Plan controller.
final AsyncNotifierProvider<StudyPlanController, StudyPlanState>
    studyPlanControllerProvider =
    AsyncNotifierProvider<StudyPlanController, StudyPlanState>(
  StudyPlanController.new,
);
