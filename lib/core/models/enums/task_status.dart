/// Completion status of a daily task.
library;

/// The status of a `daily_tasks` row.
enum TaskStatus {
  pending('PENDING'),
  inProgress('IN_PROGRESS'),
  done('DONE');

  const TaskStatus(this.wire);

  /// Value persisted in `daily_tasks.status`.
  final String wire;

  /// Whether the task is finished.
  bool get isDone => this == TaskStatus.done;

  /// Parses [value]; falls back to [TaskStatus.pending].
  static TaskStatus fromWire(String? value) {
    if (value == null) {
      return TaskStatus.pending;
    }
    for (final TaskStatus status in values) {
      if (status.wire == value) {
        return status;
      }
    }
    return TaskStatus.pending;
  }
}
