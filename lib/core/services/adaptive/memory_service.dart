/// Vocabulary memory-level algorithm (docs/ARCHITECTURE-v0.1.md §5.1).
///
/// Pure function of an injected [Clock]: it never touches IO and never calls
/// `DateTime.now()` directly, so it is fully reproducible with a `FixedClock`.
library;

import 'package:ielts_free/core/models/enums/memory_level.dart';
import 'package:ielts_free/core/models/vocabulary_review.dart';
import 'package:ielts_free/core/services/clock_service.dart';

/// Applies the spaced-repetition rules of ARCHITECTURE §5.1.
class MemoryService {
  const MemoryService({this.clock = const SystemClock()});

  /// Source of "now"; injected so tests can pin time.
  final Clock clock;

  /// Review interval for [level] (`L0` = 4h … `L6` = 60d).
  Duration intervalFor(int level) =>
      MemoryLevel.fromValue(level).reviewInterval;

  /// Folds one review result into [current] and returns the updated state.
  ///
  /// - correct → `level = min(6, level + 1)`, `streak + 1`, `correctCount + 1`;
  /// - wrong   → `level = max(0, level - 1)`, `streak = 0`, `wrongCount + 1`;
  /// - `nextReviewAt = now + interval(level)`;
  /// - after **two or more** wrong answers the interval is halved to surface the
  ///   word sooner (§5.1 edge).
  VocabularyReview applyResult(
    VocabularyReview current, {
    required bool correct,
  }) {
    final DateTime now = clock.now();
    final int level = MemoryLevel.clampValue(current.memoryLevel);

    final int newLevel;
    final int newStreak;
    final int correctCount;
    final int wrongCount;

    if (correct) {
      newLevel = level >= MemoryLevel.l6.value ? MemoryLevel.l6.value : level + 1;
      newStreak = current.streak + 1;
      correctCount = current.correctCount + 1;
      wrongCount = current.wrongCount;
    } else {
      newLevel = level <= MemoryLevel.l0.value ? MemoryLevel.l0.value : level - 1;
      newStreak = 0;
      correctCount = current.correctCount;
      wrongCount = current.wrongCount + 1;
    }

    final Duration baseInterval = intervalFor(newLevel);
    // Consecutive errors (wrongCount >= 2) shorten the interval by half so the
    // word reappears quickly (ARCHITECTURE §5.1).
    final Duration effectiveInterval = (!correct && wrongCount >= 2)
        ? Duration(microseconds: (baseInterval.inMicroseconds * 0.5).round())
        : baseInterval;

    return current.copyWith(
      memoryLevel: newLevel,
      streak: newStreak,
      correctCount: correctCount,
      wrongCount: wrongCount,
      lastReviewedAt: now,
      nextReviewAt: now.add(effectiveInterval),
      updatedAt: now,
    );
  }
}
