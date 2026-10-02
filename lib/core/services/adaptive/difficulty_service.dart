/// Difficulty-adaptation algorithm (docs/ARCHITECTURE-v0.1.md §5.4, BRIEF §33).
///
/// Rules:
/// - **R1 upgrade** — last-3 window accuracy `> 85%` → `difficulty + 1` (cap 5);
/// - **R2 downgrade** — window accuracy `< 60%` → `difficulty − 1` (floor 1);
/// - **R3 focus** — three *consecutive* wrong answers → flag focused practice.
///
/// R3 is evaluated **before** R1/R2 and the three rules are mutually exclusive.
/// Pure function: no clock, no IO.
library;

import 'package:ielts_free/core/services/adaptive/adaptive_models.dart';

/// Decides how a skill's difficulty should move.
class DifficultyService {
  const DifficultyService({
    this.windowSize = 3,
    this.upgradeThreshold = 0.85,
    this.downgradeThreshold = 0.60,
    this.consecutiveWrongForFocus = 3,
    this.minDifficulty = 1,
    this.maxDifficulty = 5,
  });

  /// Minimum window length before R1/R2 may fire.
  final int windowSize;

  /// Accuracy strictly above which R1 upgrades.
  final double upgradeThreshold;

  /// Accuracy strictly below which R2 downgrades.
  final double downgradeThreshold;

  /// Consecutive wrong answers that trigger R3.
  final int consecutiveWrongForFocus;

  /// Lower bound of the difficulty scale.
  final int minDifficulty;

  /// Upper bound of the difficulty scale.
  final int maxDifficulty;

  /// Counts the consecutive wrong answers at the **end** of [window].
  ///
  /// [window] is expected to be ordered oldest → newest.
  int trailingConsecutiveWrong(List<AnswerSample> window) {
    int count = 0;
    for (int i = window.length - 1; i >= 0; i--) {
      if (window[i].isCorrect) {
        break;
      }
      count++;
    }
    return count;
  }

  /// Evaluates [window] against [currentDifficulty] and returns the decision.
  DifficultyDecision evaluate({
    required List<AnswerSample> window,
    required int currentDifficulty,
  }) {
    final int difficulty =
        currentDifficulty.clamp(minDifficulty, maxDifficulty).toInt();

    // R3 first: repeated failure on the same point takes precedence.
    if (trailingConsecutiveWrong(window) >= consecutiveWrongForFocus) {
      return DifficultyDecision(
        action: DifficultyAction.focus,
        newDifficulty: difficulty,
        focusMode: true,
      );
    }

    // R1 / R2 require a full window.
    if (window.length >= windowSize) {
      final int correct =
          window.where((AnswerSample s) => s.isCorrect).length;
      final double accuracy = correct / window.length;
      if (accuracy > upgradeThreshold) {
        return DifficultyDecision(
          action: DifficultyAction.upgrade,
          newDifficulty:
              (difficulty + 1).clamp(minDifficulty, maxDifficulty).toInt(),
          focusMode: false,
        );
      }
      if (accuracy < downgradeThreshold) {
        return DifficultyDecision(
          action: DifficultyAction.downgrade,
          newDifficulty:
              (difficulty - 1).clamp(minDifficulty, maxDifficulty).toInt(),
          focusMode: false,
        );
      }
    }

    return DifficultyDecision(
      action: DifficultyAction.unchanged,
      newDifficulty: difficulty,
      focusMode: false,
    );
  }
}
