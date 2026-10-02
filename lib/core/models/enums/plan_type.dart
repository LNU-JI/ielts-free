/// Study-plan length options (docs/BRIEF.md §36).
///
/// The plan is not fixed: the daily tasks it drives are recomputed every day by
/// the adaptive engine.
library;

/// A selectable study-plan period.
enum PlanType {
  day7('DAY7', 7),
  day30('DAY30', 30),
  day60('DAY60', 60),
  day90('DAY90', 90),
  custom('CUSTOM', 0);

  const PlanType(this.wire, this.days);

  /// Value persisted in `study_goal.plan_type`.
  final String wire;

  /// Number of days the plan spans (`0` for [custom]).
  final int days;

  /// Parses [value]; falls back to [PlanType.day30].
  static PlanType fromWire(String? value) {
    if (value == null) {
      return PlanType.day30;
    }
    for (final PlanType type in values) {
      if (type.wire == value) {
        return type;
      }
    }
    return PlanType.day30;
  }
}
