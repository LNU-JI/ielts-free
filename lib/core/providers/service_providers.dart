/// Service providers.
///
/// Wires the domain services to the injected [Clock] and the repositories, so
/// controllers depend only on these providers
/// (docs/ARCHITECTURE-v0.1.md §1.1, §5). Algorithms stay pure; the clock and
/// data access are injected here at the boundary.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/core/providers/database_providers.dart';
import 'package:ielts_free/core/providers/repository_providers.dart';
import 'package:ielts_free/core/services/adaptive/daily_plan_service.dart';
import 'package:ielts_free/core/services/adaptive/difficulty_service.dart';
import 'package:ielts_free/core/services/adaptive/mastery_service.dart';
import 'package:ielts_free/core/services/adaptive/memory_service.dart';
import 'package:ielts_free/core/services/adaptive/phase_service.dart';
import 'package:ielts_free/core/services/adaptive/priority_service.dart';
import 'package:ielts_free/core/services/adaptive/skill_score_service.dart';
import 'package:ielts_free/core/services/adaptive/streak_service.dart';
import 'package:ielts_free/core/services/clock_service.dart';
import 'package:ielts_free/core/services/content/content_loader_service.dart';
import 'package:ielts_free/core/services/content/seed_service.dart';
import 'package:ielts_free/core/services/grading_service.dart';

// --- Infrastructure ---------------------------------------------------------

/// The app clock. Override with a `FixedClock` in tests to pin time.
final Provider<Clock> clockProvider =
    Provider<Clock>((Ref ref) => const SystemClock());

// --- Grading ----------------------------------------------------------------

/// Answer-grading service.
final Provider<GradingService> gradingServiceProvider =
    Provider<GradingService>((Ref ref) => const GradingService());

// --- Adaptive engine (§5) ---------------------------------------------------

/// Vocabulary memory-level service (§5.1).
final Provider<MemoryService> memoryServiceProvider = Provider<MemoryService>(
  (Ref ref) => MemoryService(clock: ref.watch(clockProvider)),
);

/// Skill-score service (§5.2).
final Provider<SkillScoreService> skillScoreServiceProvider =
    Provider<SkillScoreService>(
  (Ref ref) => SkillScoreService(clock: ref.watch(clockProvider)),
);

/// Training-priority service (§5.3).
final Provider<PriorityService> priorityServiceProvider =
    Provider<PriorityService>((Ref ref) => const PriorityService());

/// Difficulty-adaptation service (§5.4).
final Provider<DifficultyService> difficultyServiceProvider =
    Provider<DifficultyService>((Ref ref) => const DifficultyService());

/// Daily-plan service (§5.5).
final Provider<DailyPlanService> dailyPlanServiceProvider =
    Provider<DailyPlanService>(
  (Ref ref) => DailyPlanService(
    phaseService: PhaseService(clock: ref.watch(clockProvider)),
  ),
);

/// Exam-countdown phase service (§5.6).
final Provider<PhaseService> phaseServiceProvider = Provider<PhaseService>(
  (Ref ref) => PhaseService(clock: ref.watch(clockProvider)),
);

/// Mistake-mastery service (§5.7).
final Provider<MasteryService> masteryServiceProvider =
    Provider<MasteryService>((Ref ref) => const MasteryService());

/// Study-streak service (§5.8).
final Provider<StreakService> streakServiceProvider = Provider<StreakService>(
  (Ref ref) => StreakService(clock: ref.watch(clockProvider)),
);

// --- Content & first-run ----------------------------------------------------

/// Content-database import + verification service.
final Provider<ContentLoaderService> contentLoaderServiceProvider =
    Provider<ContentLoaderService>(
  (Ref ref) => ContentLoaderService(
    contentDatabase: ref.watch(contentDatabaseProvider),
  ),
);

/// First-run seeding service (resolves its repositories asynchronously).
final FutureProvider<SeedService> seedServiceProvider =
    FutureProvider<SeedService>((Ref ref) async {
  return SeedService(
    profileRepository: await ref.watch(userProfileRepositoryProvider.future),
    goalRepository: await ref.watch(studyGoalRepositoryProvider.future),
    settingsRepository: await ref.watch(settingsRepositoryProvider.future),
    progressRepository: await ref.watch(progressRepositoryProvider.future),
    clock: ref.watch(clockProvider),
  );
});
