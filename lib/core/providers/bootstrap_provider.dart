/// Bootstrap / startup state.
///
/// The public surface ([BootstrapState], [BootstrapStatus] and the
/// `bootstrapControllerProvider`) is stable: T03 replaced the body of
/// [BootstrapController.build] with the real startup sequence
/// (docs/ARCHITECTURE-v0.1.md §6.1) without changing the interface, so
/// `lib/app/router.dart` is untouched.
///
/// ## Progress reporting
///
/// The router treats the controller as "initializing" while it is
/// `AsyncLoading`. Emitting an `AsyncData` mid-`build` would therefore end the
/// loading state early and bounce the user to `/onboarding` before the databases
/// are ready. To show a progress bar (§6.2) **without** breaking that contract,
/// intermediate progress is published on the separate
/// [bootstrapProgressProvider]; the controller's own state only changes once,
/// when startup completes.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/database/database_factory.dart';
import 'package:ielts_free/core/models/app_settings.dart';
import 'package:ielts_free/core/providers/database_providers.dart';
import 'package:ielts_free/core/providers/repository_providers.dart';
import 'package:ielts_free/core/providers/service_providers.dart';
import 'package:ielts_free/core/services/content/content_loader_service.dart';
import 'package:ielts_free/core/services/content/seed_service.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Lifecycle stage of application startup.
enum BootstrapStatus {
  /// Databases / content are being prepared.
  initializing,

  /// Startup finished and the user still has to complete Onboarding.
  onboardingRequired,

  /// Startup finished and Onboarding is already done.
  ready,

  /// Startup failed.
  error,
}

/// Immutable snapshot of the bootstrap process.
@immutable
class BootstrapState {
  const BootstrapState({
    this.status = BootstrapStatus.initializing,
    this.onboardingCompleted = false,
    this.progress = 0.0,
    this.message,
  });

  /// Current lifecycle stage.
  final BootstrapStatus status;

  /// Whether the user has completed the five-step Onboarding flow.
  final bool onboardingCompleted;

  /// Progress in the range `[0, 1]`, for the startup progress indicator.
  final double progress;

  /// Optional status message (already localized via `strings.dart`).
  final String? message;

  /// Convenience: startup has finished successfully.
  bool get isReady => status == BootstrapStatus.ready;

  BootstrapState copyWith({
    BootstrapStatus? status,
    bool? onboardingCompleted,
    double? progress,
    String? message,
  }) {
    return BootstrapState(
      status: status ?? this.status,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      progress: progress ?? this.progress,
      message: message ?? this.message,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BootstrapState &&
        other.status == status &&
        other.onboardingCompleted == onboardingCompleted &&
        other.progress == progress &&
        other.message == message;
  }

  @override
  int get hashCode =>
      Object.hash(status, onboardingCompleted, progress, message);
}

/// Observable startup progress in `[0, 1]` (drives the §6.2 progress bar).
///
/// Kept separate from the controller state so that publishing progress does not
/// end the `AsyncLoading` phase the router depends on.
final StateProvider<double> bootstrapProgressProvider =
    StateProvider<double>((Ref ref) => 0.0);

/// Controller that drives the startup sequence (§6.1).
///
/// 1. initialise the SQLite factory (sqflite / ffi);
/// 2. open the user database (create / migrate to `kUserDbVersion`);
/// 3. import + SHA256-verify the read-only content database;
/// 4. ensure the local user, profile, goal, settings and skill scores;
/// 5. resolve to `onboardingRequired` or `ready`.
class BootstrapController extends AsyncNotifier<BootstrapState> {
  @override
  Future<BootstrapState> build() async {
    try {
      _progress(0.05);
      AppDatabaseFactory.init();

      _progress(0.20);
      await ref.read(appDatabaseProvider).database;

      _progress(0.45);
      final ContentLoaderService loader = ref.read(contentLoaderServiceProvider);
      final ContentLoadResult content = await loader.importAndVerify();
      appLogger.info(
        'Content imported: v${content.contentVersion} '
        '(${content.vocabularyCount} words / ${content.readingCount} passages / '
        '${content.readingQuestionCount} questions).',
      );

      _progress(0.75);
      final SeedService seed = await ref.read(seedServiceProvider.future);
      final SeedResult seeded = await seed.ensureSeeded();

      _progress(1.0);
      final bool onboardingCompleted = seeded.profile.onboardingCompleted;
      return BootstrapState(
        status: onboardingCompleted
            ? BootstrapStatus.ready
            : BootstrapStatus.onboardingRequired,
        onboardingCompleted: onboardingCompleted,
        progress: 1.0,
      );
    } on Object catch (error, stackTrace) {
      appLogger.severe('Bootstrap failed.', error, stackTrace);
      _progress(1.0);
      rethrow;
    }
  }

  /// Marks Onboarding as completed and persists the flag.
  ///
  /// Persistence is best-effort: a storage failure is logged but must never
  /// block the user from leaving the Onboarding flow.
  Future<void> completeOnboarding() async {
    try {
      final profileRepository =
          await ref.read(userProfileRepositoryProvider.future);
      await profileRepository.setOnboardingCompleted(
        AppConstants.localUserId,
        true,
      );
      final settingsRepository =
          await ref.read(settingsRepositoryProvider.future);
      await settingsRepository.setBool(
        AppConstants.localUserId,
        SettingKeys.onboardingCompleted,
        true,
      );
    } on Object catch (error, stackTrace) {
      appLogger.warning('Failed to persist onboarding flag.', error, stackTrace);
    }

    state = const AsyncData<BootstrapState>(
      BootstrapState(
        status: BootstrapStatus.ready,
        onboardingCompleted: true,
        progress: 1.0,
      ),
    );
  }

  /// Publishes the current startup progress on [bootstrapProgressProvider].
  void _progress(double value) {
    ref.read(bootstrapProgressProvider.notifier).state = value;
  }
}

/// Provider for the bootstrap controller.
///
/// Kept alive (not `autoDispose`) because the router reads it during redirect.
final AsyncNotifierProvider<BootstrapController, BootstrapState>
    bootstrapControllerProvider =
    AsyncNotifierProvider<BootstrapController, BootstrapState>(
  BootstrapController.new,
);
