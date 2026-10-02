/// Lifecycle status of a mistake in the review queue.
///
/// Derived from `mastery` (ARCHITECTURE §5.7): a mistake is [active] while
/// mastery < 0.80, [mastered] once mastery ≥ 0.80, and may be archived.
library;

/// Status of a mistake.
enum MistakeStatus {
  active('ACTIVE'),
  mastered('MASTERED'),
  archived('ARCHIVED');

  const MistakeStatus(this.wire);

  /// Value persisted when a status column is present.
  final String wire;

  /// Threshold at which a mistake counts as mastered (ARCHITECTURE §5.7).
  static const double masteryThreshold = 0.80;

  /// Parses [value]; falls back to [MistakeStatus.active].
  static MistakeStatus fromWire(String? value) {
    if (value == null) {
      return MistakeStatus.active;
    }
    for (final MistakeStatus status in values) {
      if (status.wire == value) {
        return status;
      }
    }
    return MistakeStatus.active;
  }
}
