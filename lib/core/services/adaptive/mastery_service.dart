/// Mistake-mastery algorithm (docs/ARCHITECTURE-v0.1.md §5.7).
///
/// - wrong → `mastery = max(0, mastery − 0.20)`, `wrongCount + 1`;
/// - redo correct → `mastery = min(1, mastery + 0.30)`;
/// - `mastery ≥ 0.80` → mastered (fades from the active queue but is kept);
/// - a mastered item answered wrong again re-enters the active queue.
///
/// Pure function: no clock, no IO.
library;

import 'package:ielts_free/core/models/enums/mistake_status.dart';
import 'package:ielts_free/core/services/adaptive/adaptive_models.dart';

/// Evolves the mastery of a mistake.
class MasteryService {
  const MasteryService({
    this.wrongPenalty = 0.20,
    this.correctReward = 0.30,
    this.threshold = MistakeStatus.masteryThreshold,
  });

  /// Mastery lost per wrong answer.
  final double wrongPenalty;

  /// Mastery gained per correct redo.
  final double correctReward;

  /// Mastery at or above which the mistake is mastered (`0.80`).
  final double threshold;

  /// Whether [mastery] counts as mastered.
  bool isMastered(double mastery) => mastery >= threshold;

  /// Applies one event to [mastery].
  ///
  /// [correct] is `true` for a successful redo. The result is clamped to
  /// `[0, 1]`. [justMastered] is set when this event crosses the threshold
  /// upward; [reentered] is set when a previously-mastered item falls back
  /// below the threshold.
  MasteryResult evolve({required double mastery, required bool correct}) {
    final double before = mastery.clamp(0.0, 1.0).toDouble();
    final bool wasMastered = isMastered(before);

    final double after = correct
        ? (before + correctReward).clamp(0.0, 1.0).toDouble()
        : (before - wrongPenalty).clamp(0.0, 1.0).toDouble();

    final bool nowMastered = isMastered(after);
    return MasteryResult(
      mastery: after,
      isMastered: nowMastered,
      justMastered: !wasMastered && nowMastered,
      reentered: wasMastered && !nowMastered,
    );
  }
}
