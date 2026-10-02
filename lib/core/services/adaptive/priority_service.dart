/// Training-priority algorithm (docs/ARCHITECTURE-v0.1.md §5.3, BRIEF §32).
///
/// `Priority = ErrorFrequency × SkillImportance × Recency × Difficulty`.
/// Pure function: it takes every input explicitly (no clock, no IO).
library;

import 'dart:math' as math;

import 'package:ielts_free/core/services/adaptive/adaptive_models.dart';

/// Ranks skills / topics by how urgently they deserve practice.
class PriorityService {
  const PriorityService({
    this.maxErrorFrequency = 5.0,
    this.recencyHalfLifeDays = 7.0,
    this.maxSkillImportance = 2.0,
  });

  /// Upper clamp of the error-frequency factor.
  final double maxErrorFrequency;

  /// `daysSinceLastError` half-life (days) of the recency factor.
  final double recencyHalfLifeDays;

  /// Upper clamp of the skill-importance factor.
  final double maxSkillImportance;

  /// `min(5, 1 + log2(1 + E))`, `[1, 5]`.
  ///
  /// `E = 0` → `1` (no errors → neutral).
  double errorFrequency(int errorCount) {
    final int safeCount = errorCount < 0 ? 0 : errorCount;
    final double value = 1 + (math.log(1 + safeCount) / math.ln2);
    return value.clamp(1.0, maxErrorFrequency).toDouble();
  }

  /// `clamp(1 + (targetScore − currentScore)/100, 1, 2)`, `[1, 2]`.
  ///
  /// When the user already beats the target the factor collapses to `1`
  /// (no extra weighting, §5.3 edge).
  double skillImportance({
    required double targetScore,
    required double currentScore,
  }) {
    final double value = 1 + (targetScore - currentScore) / 100;
    return value.clamp(1.0, maxSkillImportance).toDouble();
  }

  /// `0.5^(daysSinceLastError / 7)`, `(0, 1]`.
  double recency(double daysSinceLastError) {
    final double days = daysSinceLastError < 0 ? 0.0 : daysSinceLastError;
    return math
        .pow(0.5, days / recencyHalfLifeDays)
        .toDouble()
        .clamp(0.0, 1.0)
        .toDouble();
  }

  /// `1 + 0.2·(D̄ − 1)`, `[1, 1.8]`.
  double difficultyFactor(double averageDifficulty) {
    final double d = averageDifficulty.clamp(1.0, 5.0).toDouble();
    return (1 + 0.2 * (d - 1)).clamp(1.0, 1.8).toDouble();
  }

  /// Evaluates one candidate into a [PriorityItem].
  PriorityItem evaluate(PriorityCandidate candidate) {
    final double ef = errorFrequency(candidate.errorCount);
    final double si = skillImportance(
      targetScore: candidate.targetScore,
      currentScore: candidate.currentScore,
    );
    final double rc = recency(candidate.daysSinceLastError);
    final double df = difficultyFactor(candidate.averageDifficulty);
    return PriorityItem(
      key: candidate.key,
      priority: ef * si * rc * df,
      errorFrequency: ef,
      skillImportance: si,
      recency: rc,
      difficulty: df,
    );
  }

  /// Evaluates and sorts [candidates] by descending priority.
  ///
  /// Ties are broken by key so the ordering is deterministic (test-friendly).
  List<PriorityItem> rank(List<PriorityCandidate> candidates) {
    final List<PriorityItem> items =
        candidates.map(evaluate).toList(growable: false);
    final List<PriorityItem> sorted = List<PriorityItem>.of(items)
      ..sort((PriorityItem a, PriorityItem b) {
        final int byPriority = b.priority.compareTo(a.priority);
        return byPriority != 0 ? byPriority : a.key.compareTo(b.key);
      });
    return List<PriorityItem>.unmodifiable(sorted);
  }

  /// The highest priority among [items], or `0` when empty.
  ///
  /// `0` is a safe sentinel because callers guard against it before dividing
  /// (§5.5 `prioBoost` uses `priorityOf(skill) / maxPriority`).
  double maxPriority(List<PriorityItem> items) {
    double max = 0;
    for (final PriorityItem item in items) {
      if (item.priority > max) {
        max = item.priority;
      }
    }
    return max;
  }
}
