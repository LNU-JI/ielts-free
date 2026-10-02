/// Types of daily task produced by the daily-plan algorithm
/// (docs/BRIEF.md §34, ARCHITECTURE §5.5).
library;

/// The kind of work a daily task represents.
enum TaskType {
  vocabReview('VOCAB_REVIEW'),
  vocabPractice('VOCAB_PRACTICE'),
  reading('READING'),
  mistakeReview('MISTAKE_REVIEW');

  const TaskType(this.wire);

  /// Value persisted in `daily_tasks.task_type`.
  final String wire;

  /// Parses [value]; returns `null` when unknown or null.
  static TaskType? maybeFromWire(String? value) {
    if (value == null) {
      return null;
    }
    for (final TaskType type in values) {
      if (type.wire == value) {
        return type;
      }
    }
    return null;
  }

  /// Parses [value]; falls back to [TaskType.vocabReview].
  static TaskType fromWire(String? value) =>
      maybeFromWire(value) ?? TaskType.vocabReview;
}
