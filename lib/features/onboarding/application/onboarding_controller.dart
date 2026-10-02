/// Onboarding flow controller (docs/ARCHITECTURE-v0.1.md §2.2, PRD §4.1).
///
/// Owns the five-step state (goal band → exam date → daily minutes → weakest
/// skill → initial test) and, on finish, persists everything in one place:
///
/// 1. `user_profile` — weakest skill + `onboarding_completed = true`;
/// 2. `study_goal`    — target band, exam date, daily minutes, plan window;
/// 3. `skill_scores`  — the five initial (estimated) dimension scores;
/// 4. `app_settings`  — the onboarding flag.
///
/// Finally it invalidates [bootstrapControllerProvider] so the router notices
/// the completed flag and leaves `/onboarding`. The flow is fully offline: no
/// network is ever touched.
///
/// V0.1 has no Listening / Writing / Speaking item bank, so those dimensions use
/// the step-4 self-rating as a conservative starting point (ARCHITECTURE R7 /
/// PRD Q-2). The UI labels the resulting numbers as「估算」.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/core/models/app_settings.dart';
import 'package:ielts_free/core/models/enums/plan_type.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/skill_score.dart';
import 'package:ielts_free/core/models/study_goal.dart';
import 'package:ielts_free/core/models/user_profile.dart';
import 'package:ielts_free/core/providers/bootstrap_provider.dart';
import 'package:ielts_free/core/providers/refresh_provider.dart';
import 'package:ielts_free/core/providers/repository_providers.dart';
import 'package:ielts_free/core/providers/service_providers.dart';
import 'package:ielts_free/core/services/clock_service.dart';
import 'package:ielts_free/core/storage/repositories/progress_repository.dart';
import 'package:ielts_free/core/storage/repositories/settings_repository.dart';
import 'package:ielts_free/core/storage/repositories/study_goal_repository.dart';
import 'package:ielts_free/core/storage/repositories/user_profile_repository.dart';
import 'package:ielts_free/core/utils/date_utils.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// The five Onboarding steps, in order.
enum OnboardingStep { targetBand, examDate, dailyMinutes, weakestSkill, initialTest }

/// Immutable Onboarding state.
@immutable
class OnboardingState {
  const OnboardingState({
    this.stepIndex = 0,
    this.targetBand = AppConstants.defaultTargetBand,
    this.examDays,
    this.dailyMinutes = AppConstants.defaultDailyStudyMinutes,
    this.weakestSkill,
    this.testAnswers = const <int>[],
    this.submitting = false,
    this.error,
  });

  /// Index of the current step (`0..4`).
  final int stepIndex;

  /// Selected target band (e.g. `7.0`).
  final double targetBand;

  /// Days until the exam (`null` = 暂未确定).
  final int? examDays;

  /// Daily study budget in minutes.
  final int dailyMinutes;

  /// Self-declared weakest skill (`null` = 不知道).
  final SkillType? weakestSkill;

  /// Answers to the 15-item self-assessment (`0..2`), may be shorter than 15.
  final List<int> testAnswers;

  /// Whether the finish sequence is running.
  final bool submitting;

  /// A user-facing error message, or `null`.
  final String? error;

  /// The current [OnboardingStep].
  OnboardingStep get step => OnboardingStep.values[stepIndex];

  /// Number of steps.
  static const int totalSteps = 5;

  /// The self-assessment question count (3 × 5 dimensions).
  static const int testLength = AppConstants.initialTestQuestionCount;

  /// Whether the flow is on the last step.
  bool get isLastStep => stepIndex >= totalSteps - 1;

  /// Whether the user may go back.
  bool get canGoBack => stepIndex > 0;

  /// Progress in `[0, 1]`.
  double get progress => (stepIndex + 1) / totalSteps;

  /// The answer at [index], or `-1` when unanswered.
  int answerAt(int index) =>
      index >= 0 && index < testAnswers.length ? testAnswers[index] : -1;

  /// Whether every self-assessment item has been answered.
  bool get isTestComplete {
    if (testAnswers.length < testLength) {
      return false;
    }
    for (int i = 0; i < testLength; i++) {
      if (testAnswers[i] < 0) {
        return false;
      }
    }
    return true;
  }

  /// Whether the current step allows moving forward.
  bool get canProceed => step == OnboardingStep.initialTest
      ? isTestComplete
      : true;

  OnboardingState copyWith({
    int? stepIndex,
    double? targetBand,
    int? examDays,
    bool clearExamDays = false,
    int? dailyMinutes,
    SkillType? weakestSkill,
    bool clearWeakestSkill = false,
    List<int>? testAnswers,
    bool? submitting,
    String? error,
    bool clearError = false,
  }) {
    return OnboardingState(
      stepIndex: stepIndex ?? this.stepIndex,
      targetBand: targetBand ?? this.targetBand,
      examDays: clearExamDays ? null : (examDays ?? this.examDays),
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      weakestSkill:
          clearWeakestSkill ? null : (weakestSkill ?? this.weakestSkill),
      testAnswers: testAnswers ?? this.testAnswers,
      submitting: submitting ?? this.submitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Drives the five-step Onboarding flow.
class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  // --- step selections ----------------------------------------------------

  /// Step 1 — target band.
  void selectTargetBand(double band) {
    state = state.copyWith(targetBand: band);
  }

  /// Step 2 — exam distance in days (`null` = 暂未确定).
  void selectExamDays(int? days) {
    state = days == null
        ? state.copyWith(clearExamDays: true)
        : state.copyWith(examDays: days);
  }

  /// Step 3 — daily study minutes.
  void selectDailyMinutes(int minutes) {
    state = state.copyWith(dailyMinutes: minutes);
  }

  /// Step 4 — self-declared weakest skill (`null` = 不知道).
  void selectWeakestSkill(SkillType? skill) {
    state = skill == null
        ? state.copyWith(clearWeakestSkill: true)
        : state.copyWith(weakestSkill: skill);
  }

  /// Step 5 — records the answer (`0..2`) of item [index].
  void setTestAnswer(int index, int value) {
    if (index < 0 || index >= OnboardingState.testLength) {
      return;
    }
    final int safe = value.clamp(0, 2).toInt();
    final List<int> answers = List<int>.filled(
      OnboardingState.testLength,
      -1,
      growable: false,
    );
    for (int i = 0; i < OnboardingState.testLength; i++) {
      answers[i] = state.answerAt(i);
    }
    answers[index] = safe;
    state = state.copyWith(testAnswers: answers);
  }

  // --- navigation ---------------------------------------------------------

  /// Advances one step when allowed.
  void next() {
    if (state.isLastStep || !state.canProceed) {
      return;
    }
    state = state.copyWith(stepIndex: state.stepIndex + 1, clearError: true);
  }

  /// Goes back one step.
  void back() {
    if (!state.canGoBack) {
      return;
    }
    state = state.copyWith(stepIndex: state.stepIndex - 1, clearError: true);
  }

  // --- finish -------------------------------------------------------------

  /// Persists the collected data and leaves Onboarding.
  Future<void> finish() async {
    if (state.submitting) {
      return;
    }
    state = state.copyWith(submitting: true, clearError: true);

    final Clock clock = ref.read(clockProvider);
    final DateTime now = clock.now();
    const String userId = AppConstants.localUserId;
    final String today = AppDateUtils.localDateString(now);

    try {
      // 1. Profile: weakest skill + completed flag.
      final UserProfileRepository profileRepository =
          await ref.read(userProfileRepositoryProvider.future);
      final UserProfile existing =
          await profileRepository.get(userId) ?? UserProfile.localDefault(now: now);
      await profileRepository.save(
        existing.copyWith(
          weakestSkill: state.weakestSkill ?? existing.weakestSkill,
          onboardingCompleted: true,
          updatedAt: now,
        ),
      );

      // 2. Study goal.
      final StudyGoalRepository goalRepository =
          await ref.read(studyGoalRepositoryProvider.future);
      final StudyGoal existingGoal =
          await goalRepository.ensureDefault(userId: userId);
      final String? examDate = _examDateString(today);
      await goalRepository.saveActive(
        StudyGoal(
          userId: userId,
          targetBand: state.targetBand,
          examDate: examDate,
          dailyStudyMinutes: state.dailyMinutes,
          planType: _planTypeFor(state.examDays),
          planStartDate: today,
          planEndDate: examDate ?? AppDateUtils.addDaysToLocalDate(today, 30),
          isActive: true,
          createdAt: existingGoal.createdAt ?? now,
          updatedAt: now,
        ),
      );

      // 3. Five initial skill scores.
      final ProgressRepository progressRepository =
          await ref.read(progressRepositoryProvider.future);
      final Map<SkillType, double> scores = _estimateScores();
      for (final MapEntry<SkillType, double> entry in scores.entries) {
        await progressRepository.saveSkillScore(
          SkillScore(
            userId: userId,
            skill: entry.key,
            score: entry.value,
            currentDifficulty: 2,
            sampleCount: 0,
            updatedAt: now,
          ),
        );
      }

      // 4. Settings flag (best-effort mirror of the profile flag).
      final SettingsRepository settingsRepository =
          await ref.read(settingsRepositoryProvider.future);
      await settingsRepository.setBool(
        userId,
        SettingKeys.onboardingCompleted,
        true,
      );

      state = state.copyWith(submitting: false, clearError: true);

      // 5. Refresh downstream screens, then let the router react by re-reading
      //    bootstrap (onboardingCompleted is now true).
      notifyDataChanged(ref);
      ref.invalidate(bootstrapControllerProvider);
    } on Object catch (error, stackTrace) {
      appLogger.warning('Onboarding finish failed.', error, stackTrace);
      state = state.copyWith(
        submitting: false,
        error: AppStrings.settingsSaveFailed,
      );
    }
  }

  // --- helpers ------------------------------------------------------------

  String? _examDateString(String today) {
    final int? days = state.examDays;
    if (days == null || days <= 0) {
      return null;
    }
    return AppDateUtils.addDaysToLocalDate(today, days);
  }

  PlanType _planTypeFor(int? days) {
    switch (days) {
      case 30:
        return PlanType.day30;
      case 60:
        return PlanType.day60;
      case 90:
        return PlanType.day90;
      case 180:
        return PlanType.custom;
      default:
        return PlanType.day30;
    }
  }

  /// Conservative initial scores from the 15-item self-assessment.
  ///
  /// Each dimension is scored by three statements (sum `0..6` → `25..75`), then
  /// the step-4 weakest skill loses a small amount so the planner starts with a
  /// sensible gap. Everything stays in `[10, 80]` — deliberately never high.
  Map<SkillType, double> _estimateScores() {
    const List<SkillType> dims = SkillType.fiveDimensions;
    final Map<SkillType, double> scores = <SkillType, double>{};

    for (int d = 0; d < dims.length; d++) {
      int sum = 0;
      for (int q = 0; q < 3; q++) {
        final int answer = state.answerAt(d * 3 + q);
        sum += answer < 0 ? 1 : answer; // unanswered → neutral
      }
      double score = 25 + (sum / 6) * 50; // 25..75
      if (state.weakestSkill == dims[d]) {
        score -= 5;
      }
      scores[dims[d]] = score.clamp(10.0, 80.0).toDouble().roundToDouble();
    }
    return scores;
  }
}

/// Provider for the Onboarding controller.
final NotifierProvider<OnboardingController, OnboardingState>
    onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
  OnboardingController.new,
);
