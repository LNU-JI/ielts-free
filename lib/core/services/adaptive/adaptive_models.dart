/// Shared value objects for the adaptive engine.
///
/// Every algorithm in `lib/core/services/adaptive/` is a **pure function** whose
/// inputs and outputs are the immutable value objects defined here
/// (docs/ARCHITECTURE-v0.1.md §5). Keeping them in one place guarantees the
/// algorithms and their callers agree on field names and semantics, and makes
/// the engine trivially unit-testable with `FixedClock`.
library;

import 'package:ielts_free/core/models/enums/error_type.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/enums/task_type.dart';

/// One answer observation fed to the adaptive algorithms.
///
/// Mirrors the fields of `user_answers` (ARCHITECTURE §4.3) that the algorithms
/// consume, without pulling the persistence model into the pure layer.
class AnswerSample {
  const AnswerSample({
    required this.isCorrect,
    required this.difficulty,
    required this.answeredAt,
    this.skill,
    this.errorType,
    this.topic,
  });

  /// Whether the answer was correct.
  final bool isCorrect;

  /// Item difficulty in `1..5`.
  final int difficulty;

  /// When the answer was submitted (UTC).
  final DateTime answeredAt;

  /// The skill exercised, when known.
  final SkillType? skill;

  /// The classified error type (for wrong answers), when known.
  final ErrorType? errorType;

  /// A free-form topic key (e.g. a vocabulary topic) used for grouping.
  final String? topic;
}

/// Candidate passed to the priority ranking (§5.3).
class PriorityCandidate {
  const PriorityCandidate({
    required this.key,
    required this.errorCount,
    required this.targetScore,
    required this.currentScore,
    required this.daysSinceLastError,
    required this.averageDifficulty,
  });

  /// Grouping key: a skill wire value, a topic, or an error type.
  final String key;

  /// `E` — number of wrong answers for this key in the last 14 days.
  final int errorCount;

  /// Target score in `[0, 100]`.
  final double targetScore;

  /// Current score in `[0, 100]`.
  final double currentScore;

  /// Days since the most recent error for this key.
  final double daysSinceLastError;

  /// Mean difficulty `D̄` of the errors, in `[1, 5]`.
  final double averageDifficulty;
}

/// One ranked priority entry (§5.3 output).
class PriorityItem {
  const PriorityItem({
    required this.key,
    required this.priority,
    required this.errorFrequency,
    required this.skillImportance,
    required this.recency,
    required this.difficulty,
  });

  /// The grouping key this entry describes.
  final String key;

  /// `ErrorFrequency × SkillImportance × Recency × Difficulty`.
  final double priority;

  /// Factor 1, in `[1, 5]`.
  final double errorFrequency;

  /// Factor 2, in `[1, 2]`.
  final double skillImportance;

  /// Factor 3, in `(0, 1]`.
  final double recency;

  /// Factor 4, in `[1, 1.8]`.
  final double difficulty;
}

/// The action recommended by the difficulty service (§5.4).
enum DifficultyAction {
  /// Raise `current_difficulty` by one (capped at 5).
  upgrade,

  /// Lower `current_difficulty` by one (floored at 1).
  downgrade,

  /// Enter focused practice for a repeatedly-wrong topic.
  focus,

  /// Keep the current difficulty.
  unchanged,
}

/// Outcome of a difficulty evaluation (§5.4).
class DifficultyDecision {
  const DifficultyDecision({
    required this.action,
    required this.newDifficulty,
    required this.focusMode,
  });

  /// The recommended action.
  final DifficultyAction action;

  /// The difficulty that should be persisted.
  final int newDifficulty;

  /// Whether the topic should be flagged for focused practice (R3).
  final bool focusMode;
}

/// The three daily-plan buckets that exist in V0.1 (§5.5).
///
/// Listening / Writing / Speaking carry no item bank yet, so their base weights
/// are folded into these three buckets.
enum DailyPlanBucket { vocabulary, reading, mistakes }

/// Immutable input for the daily-plan algorithm (§5.5).
class DailyPlanInput {
  const DailyPlanInput({
    required this.targetBand,
    required this.skillScores,
    required this.daysRemaining,
    required this.dailyMinutes,
    this.priorities = const <SkillType, double>{},
    this.weakestSkill,
  });

  /// Target band score (e.g. `7.0`), used for the gap boost.
  final double targetBand;

  /// Current score per headline skill, in `[0, 100]`.
  final Map<SkillType, double> skillScores;

  /// Days left until the exam, or `null` when unset.
  final int? daysRemaining;

  /// Total study minutes to distribute.
  final int dailyMinutes;

  /// Priority per skill (from §5.3); missing entries default to `1`.
  final Map<SkillType, double> priorities;

  /// The skill the user self-identified as weakest (Onboarding step 4).
  final SkillType? weakestSkill;
}

/// One scheduled task produced by the daily-plan algorithm (§5.5).
class DailyPlanItem {
  const DailyPlanItem({
    required this.bucket,
    required this.taskType,
    required this.skill,
    required this.minutes,
    required this.itemCount,
    required this.reason,
    required this.priority,
  });

  /// The bucket this task belongs to.
  final DailyPlanBucket bucket;

  /// The persisted task type.
  final TaskType taskType;

  /// The skill this task trains, or `null` for the mixed mistakes bucket.
  final SkillType? skill;

  /// Allocated minutes (always `>= 5`).
  final int minutes;

  /// Number of items (words / passages / questions) to attempt.
  final int itemCount;

  /// Human-readable explanation of why this task got its allocation.
  final String reason;

  /// The bucket priority used for ordering.
  final double priority;
}

/// Outcome of evolving a mistake's mastery (§5.7).
class MasteryResult {
  const MasteryResult({
    required this.mastery,
    required this.isMastered,
    required this.justMastered,
    required this.reentered,
  });

  /// The new mastery in `[0, 1]`.
  final double mastery;

  /// Whether the mistake is now considered mastered (`mastery >= 0.80`).
  final bool isMastered;

  /// Whether this event crossed the mastery threshold upward.
  final bool justMastered;

  /// Whether a previously-mastered mistake fell back into the active queue.
  final bool reentered;
}

/// Outcome of a study event for the streak counter (§5.8).
class StreakResult {
  const StreakResult({
    required this.streak,
    required this.lastStudyDate,
    required this.changed,
  });

  /// The resulting streak length.
  final int streak;

  /// The local `YYYY-MM-DD` date that should be stored as `last_study_date`.
  final String lastStudyDate;

  /// Whether the streak / last-study-date changed.
  ///
  /// `false` means the event was a no-op (same day repeated, or a clock
  /// rollback) and the stored values must be left untouched.
  final bool changed;
}
