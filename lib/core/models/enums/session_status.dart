/// Lifecycle status of a learning session (crash-recovery support, BRIEF §79).
library;

/// The status of a `learning_sessions` row.
enum SessionStatus {
  active('ACTIVE'),
  completed('COMPLETED'),
  aborted('ABORTED');

  const SessionStatus(this.wire);

  /// Value persisted in `learning_sessions.status`.
  final String wire;

  /// Parses [value]; falls back to [SessionStatus.active].
  static SessionStatus fromWire(String? value) {
    if (value == null) {
      return SessionStatus.active;
    }
    for (final SessionStatus status in values) {
      if (status.wire == value) {
        return status;
      }
    }
    return SessionStatus.active;
  }
}
