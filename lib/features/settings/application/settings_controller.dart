/// Settings controller (PRD §4.2 / §6.2, BRIEF §42/§43/§87).
///
/// Owns everything the Settings screen can change:
/// - the study goal (target band, exam date, daily minutes) → `study_goal`;
/// - appearance (theme mode, font scale) and sound → `app_settings`;
/// - data actions (Export / Delete My Data) → `backup_repository`.
///
/// The theme mode and font scale are read at application root so a change here
/// is applied app-wide. Writes that affect other screens call
/// [notifyDataChanged] (ARCHITECTURE §9.3, FR-064).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/models/app_settings.dart';
import 'package:ielts_free/core/models/study_goal.dart';
import 'package:ielts_free/core/providers/bootstrap_provider.dart';
import 'package:ielts_free/core/providers/refresh_provider.dart';
import 'package:ielts_free/core/providers/repository_providers.dart';
import 'package:ielts_free/core/providers/service_providers.dart';
import 'package:ielts_free/core/services/content/seed_service.dart';
import 'package:ielts_free/core/storage/repositories/backup_repository.dart';
import 'package:ielts_free/core/storage/repositories/settings_repository.dart';
import 'package:ielts_free/core/storage/repositories/study_goal_repository.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Immutable Settings state.
@immutable
class AppSettingsState {
  const AppSettingsState({
    this.themeMode = ThemeMode.system,
    this.fontScale = 1.0,
    this.soundEnabled = true,
    this.targetBand = AppConstants.defaultTargetBand,
    this.examDate,
    this.dailyStudyMinutes = AppConstants.defaultDailyStudyMinutes,
    this.busy = false,
    this.loaded = false,
  });

  /// Selected theme mode (PRD Q-6).
  final ThemeMode themeMode;

  /// Global font-size scale factor.
  final double fontScale;

  /// Whether sound effects are on.
  final bool soundEnabled;

  /// Target band.
  final double targetBand;

  /// Exam date (`YYYY-MM-DD`), or `null`.
  final String? examDate;

  /// Daily study minutes.
  final int dailyStudyMinutes;

  /// Whether a write is in flight.
  final bool busy;

  /// Whether the initial load finished.
  final bool loaded;

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    double? fontScale,
    bool? soundEnabled,
    double? targetBand,
    String? examDate,
    bool clearExamDate = false,
    int? dailyStudyMinutes,
    bool? busy,
    bool? loaded,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      fontScale: fontScale ?? this.fontScale,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      targetBand: targetBand ?? this.targetBand,
      examDate: clearExamDate ? null : (examDate ?? this.examDate),
      dailyStudyMinutes: dailyStudyMinutes ?? this.dailyStudyMinutes,
      busy: busy ?? this.busy,
      loaded: loaded ?? this.loaded,
    );
  }
}

/// Controller for the Settings screen.
class SettingsController extends AsyncNotifier<AppSettingsState> {
  /// Font-scale presets offered by the UI (小 / 标准 / 大 / 特大).
  static const List<double> fontScalePresets = <double>[0.9, 1.0, 1.15, 1.3];

  /// Target-band presets offered by the UI.
  static const List<double> targetBandPresets = <double>[
    6.0,
    6.5,
    7.0,
    7.5,
    8.0,
  ];

  /// Daily-minute presets offered by the UI.
  static const List<int> dailyMinutePresets = <int>[30, 60, 90, 120];

  @override
  Future<AppSettingsState> build() => _load();

  /// Reads the persisted settings and the active goal.
  ///
  /// Uses `ref.read` (not `watch`) so the mutators can reuse it without
  /// re-subscribing; the controller refreshes itself explicitly after a write.
  /// The goal is read **without** creating one, so this early startup read never
  /// races the bootstrap seeding sequence.
  Future<AppSettingsState> _load() async {
    try {
      final SettingsRepository settings =
          await ref.read(settingsRepositoryProvider.future);
      final StudyGoalRepository goals =
          await ref.read(studyGoalRepositoryProvider.future);
      final Map<String, String> all =
          await settings.all(AppConstants.localUserId);
      final StudyGoal? goal = await goals.active(AppConstants.localUserId);

      return AppSettingsState(
        themeMode: _parseThemeMode(all[SettingKeys.themeMode]),
        fontScale: _parseDouble(all[SettingKeys.fontScale], 1.0),
        soundEnabled: _parseBool(all[SettingKeys.soundEnabled], true),
        targetBand: goal?.targetBand ?? AppConstants.defaultTargetBand,
        examDate: goal?.examDate,
        dailyStudyMinutes:
            goal?.dailyStudyMinutes ?? AppConstants.defaultDailyStudyMinutes,
        loaded: true,
      );
    } on Object catch (error, stackTrace) {
      // Never block the UI on a settings read; fall back to defaults.
      appLogger.warning('Settings load failed.', error, stackTrace);
      return const AppSettingsState(loaded: true);
    }
  }

  // --- study goal ---------------------------------------------------------

  /// Updates the target band.
  Future<void> setTargetBand(double band) =>
      _updateGoal((StudyGoal goal) => _copyGoal(goal, targetBand: band));

  /// Updates the exam date (`null` clears it).
  Future<void> setExamDate(String? date) => _updateGoal(
        (StudyGoal goal) => _copyGoal(goal, examDate: date, clearExamDate: date == null),
      );

  /// Updates the daily study minutes.
  Future<void> setDailyStudyMinutes(int minutes) => _updateGoal(
        (StudyGoal goal) => _copyGoal(goal, dailyStudyMinutes: minutes),
      );

  // --- appearance / sound -------------------------------------------------

  /// Updates the theme mode.
  Future<void> setThemeMode(ThemeMode mode) =>
      _updateSetting(SettingKeys.themeMode, _themeModeValue(mode));

  /// Updates the font scale.
  Future<void> setFontScale(double scale) =>
      _updateSetting(SettingKeys.fontScale, scale.toStringAsFixed(2));

  /// Updates the sound toggle.
  Future<void> setSoundEnabled(bool enabled) =>
      _updateSetting(SettingKeys.soundEnabled, enabled ? 'true' : 'false');

  // --- data actions -------------------------------------------------------

  /// Exports a JSON backup and returns the file path.
  Future<String> exportData() async {
    final BackupRepository backup =
        await ref.read(backupRepositoryProvider.future);
    return backup.exportToJson(AppConstants.localUserId);
  }

  /// Deletes all local data, re-seeds the baseline and returns to Onboarding.
  Future<void> deleteAllData() async {
    final BackupRepository backup =
        await ref.read(backupRepositoryProvider.future);
    await backup.deleteAllUserData(AppConstants.localUserId);

    // Recreate the guest baseline (profile with onboarding_completed = false).
    final SeedService seed = await ref.read(seedServiceProvider.future);
    await seed.ensureSeeded(userId: AppConstants.localUserId);

    notifyDataChanged(ref);
    // Re-run startup so the router sends the user back to Onboarding.
    ref.invalidate(bootstrapControllerProvider);
  }

  // --- internals ----------------------------------------------------------

  Future<void> _updateGoal(StudyGoal Function(StudyGoal) mutate) async {
    final AppSettingsState previous =
        state.valueOrNull ?? const AppSettingsState();
    state = AsyncData<AppSettingsState>(previous.copyWith(busy: true));

    try {
      final StudyGoalRepository goals =
          await ref.read(studyGoalRepositoryProvider.future);
      final StudyGoal goal =
          await goals.ensureDefault(userId: AppConstants.localUserId);
      await goals.saveActive(mutate(goal));
      state = AsyncData<AppSettingsState>(await _load());
      notifyDataChanged(ref);
    } on Object catch (error, stackTrace) {
      appLogger.warning('Goal update failed.', error, stackTrace);
      state = AsyncData<AppSettingsState>(previous.copyWith(busy: false));
      rethrow;
    }
  }

  Future<void> _updateSetting(String key, String value) async {
    final AppSettingsState previous =
        state.valueOrNull ?? const AppSettingsState();

    try {
      final SettingsRepository settings =
          await ref.read(settingsRepositoryProvider.future);
      await settings.set(AppConstants.localUserId, key, value);
      state = AsyncData<AppSettingsState>(await _load());
    } on Object catch (error, stackTrace) {
      appLogger.warning('Setting "$key" update failed.', error, stackTrace);
      state = AsyncData<AppSettingsState>(previous);
      rethrow;
    }
  }

  StudyGoal _copyGoal(
    StudyGoal goal, {
    double? targetBand,
    String? examDate,
    bool clearExamDate = false,
    int? dailyStudyMinutes,
  }) {
    return StudyGoal(
      userId: goal.userId,
      targetBand: targetBand ?? goal.targetBand,
      examDate: clearExamDate ? null : (examDate ?? goal.examDate),
      dailyStudyMinutes: dailyStudyMinutes ?? goal.dailyStudyMinutes,
      planType: goal.planType,
      planStartDate: goal.planStartDate,
      planEndDate: goal.planEndDate,
      isActive: true,
      createdAt: goal.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeValue(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  double _parseDouble(String? value, double fallback) {
    if (value == null) {
      return fallback;
    }
    return double.tryParse(value) ?? fallback;
  }

  bool _parseBool(String? value, bool fallback) {
    if (value == null) {
      return fallback;
    }
    final String lowered = value.toLowerCase();
    return lowered == '1' || lowered == 'true';
  }
}

/// Provider for the Settings controller.
final AsyncNotifierProvider<SettingsController, AppSettingsState>
    settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettingsState>(
  SettingsController.new,
);

/// The active [ThemeMode], read at application root (`app.dart`).
///
/// Falls back to `ThemeMode.system` until the settings finish loading so the
/// first frame is always valid.
final Provider<ThemeMode> themeModeProvider = Provider<ThemeMode>((Ref ref) {
  return ref.watch(settingsControllerProvider).valueOrNull?.themeMode ??
      ThemeMode.system;
});

/// The active font scale, read at application root (`app.dart`).
final Provider<double> fontScaleProvider = Provider<double>((Ref ref) {
  return ref.watch(settingsControllerProvider).valueOrNull?.fontScale ?? 1.0;
});
