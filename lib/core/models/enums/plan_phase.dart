/// Exam-countdown study phase (docs/BRIEF.md §35, ARCHITECTURE §5.6).
///
/// - `daysRemaining > 90` → [foundation]
/// - `30 ≤ daysRemaining ≤ 90` → [focus]
/// - `daysRemaining < 30` → [comprehensive]
/// - no exam date → [foundation]
library;

/// The study phase derived from the number of days left before the exam.
enum PlanPhase {
  foundation('FOUNDATION'),
  focus('FOCUS'),
  comprehensive('COMPREHENSIVE');

  const PlanPhase(this.wire);

  /// Value persisted in the `phase` column.
  final String wire;

  /// Derives the phase from [daysRemaining] (`null` → [foundation]).
  static PlanPhase fromDaysRemaining(int? daysRemaining) {
    if (daysRemaining == null) {
      return PlanPhase.foundation;
    }
    if (daysRemaining > 90) {
      return PlanPhase.foundation;
    }
    if (daysRemaining >= 30) {
      return PlanPhase.focus;
    }
    return PlanPhase.comprehensive;
  }

  /// Parses [value]; falls back to [PlanPhase.foundation].
  static PlanPhase fromWire(String? value) {
    if (value == null) {
      return PlanPhase.foundation;
    }
    for (final PlanPhase phase in values) {
      if (phase.wire == value) {
        return phase;
      }
    }
    return PlanPhase.foundation;
  }
}
