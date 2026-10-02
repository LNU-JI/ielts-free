/// First-run data preparation (docs/ARCHITECTURE-v0.1.md §6.1, BRIEF §11).
///
/// Idempotently ensures the local guest user, its default profile and goal, the
/// default settings and the five initial skill-score rows exist. Safe to call on
/// every launch: it only inserts what is missing.
library;

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/models/app_settings.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/skill_score.dart';
import 'package:ielts_free/core/models/study_goal.dart';
import 'package:ielts_free/core/models/user_profile.dart';
import 'package:ielts_free/core/services/clock_service.dart';
import 'package:ielts_free/core/storage/repositories/progress_repository.dart';
import 'package:ielts_free/core/storage/repositories/settings_repository.dart';
import 'package:ielts_free/core/storage/repositories/study_goal_repository.dart';
import 'package:ielts_free/core/storage/repositories/user_profile_repository.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Summary of what the seed step produced.
class SeedResult {
  const SeedResult({
    required this.profile,
    required this.goal,
    required this.createdProfile,
    required this.insertedSkillScores,
  });

  /// The (existing or freshly created) user profile.
  final UserProfile profile;

  /// The active study goal.
  final StudyGoal goal;

  /// Whether the profile was created by this call.
  final bool createdProfile;

  /// How many skill-score rows were inserted by this call.
  final int insertedSkillScores;
}

/// Ensures the local user's baseline data exists.
class SeedService {
  SeedService({
    required UserProfileRepository profileRepository,
    required StudyGoalRepository goalRepository,
    required SettingsRepository settingsRepository,
    required ProgressRepository progressRepository,
    Clock clock = const SystemClock(),
  })  : _profiles = profileRepository,
        _goals = goalRepository,
        _settings = settingsRepository,
        _progress = progressRepository,
        _clock = clock;

  final UserProfileRepository _profiles;
  final StudyGoalRepository _goals;
  final SettingsRepository _settings;
  final ProgressRepository _progress;
  final Clock _clock;

  /// Neutral starting score for a skill before any answer is recorded.
  ///
  /// The real Onboarding initial test (15 questions) overwrites this; before
  /// Onboarding the score is a placeholder so charts have a value to show.
  static const double initialSkillScore = 40.0;

  /// Default settings applied to a fresh user (missing keys only).
  static const Map<String, String> defaultSettings = <String, String>{
    SettingKeys.themeMode: 'system',
    SettingKeys.fontScale: '1.0',
    SettingKeys.soundEnabled: 'true',
    SettingKeys.notificationsEnabled: 'false',
    SettingKeys.dailyTargetMinutes: '60',
  };

  /// Ensures the local user and all baseline rows exist for [userId].
  Future<SeedResult> ensureSeeded({String userId = AppConstants.localUserId}) async {
    // 1. users row + profile.
    final UserProfile? existingProfile = await _profiles.get(userId);
    final UserProfile profile =
        await _profiles.ensureDefault(userId: userId);

    // 2. default study goal.
    final StudyGoal goal = await _goals.ensureDefault(userId: userId);

    // 3. default settings (never overwrite a user choice).
    await _seedSettings(userId);

    // 4. five initial skill scores.
    final int inserted = await _seedSkillScores(userId);

    appLogger.info(
      'Seed ready for $userId (newProfile=${existingProfile == null}, '
      'skillScoresInserted=$inserted).',
    );

    return SeedResult(
      profile: profile,
      goal: goal,
      createdProfile: existingProfile == null,
      insertedSkillScores: inserted,
    );
  }

  Future<void> _seedSettings(String userId) async {
    final Map<String, String> existing = await _settings.all(userId);
    for (final MapEntry<String, String> entry in defaultSettings.entries) {
      if (!existing.containsKey(entry.key)) {
        await _settings.set(userId, entry.key, entry.value);
      }
    }
  }

  Future<int> _seedSkillScores(String userId) async {
    final List<SkillScore> existing = await _progress.allSkillScores(userId);
    final Set<SkillType> present = existing
        .map((SkillScore s) => s.skill)
        .toSet();

    final DateTime now = _clock.now();
    int inserted = 0;
    for (final SkillType skill in SkillType.fiveDimensions) {
      if (present.contains(skill)) {
        continue;
      }
      await _progress.saveSkillScore(
        SkillScore(
          userId: userId,
          skill: skill,
          score: initialSkillScore,
          currentDifficulty: 2,
          sampleCount: 0,
          updatedAt: now,
        ),
      );
      inserted++;
    }
    return inserted;
  }
}
