/// Reference target of a user-generated row (answer, mistake, favourite, note).
library;

/// What a `ref_id` points at.
enum RefType {
  vocabulary('VOCABULARY'),
  reading('READING');

  const RefType(this.wire);

  /// Value persisted in `ref_type` columns.
  final String wire;

  /// Parses [value]; returns `null` when unknown or null.
  static RefType? maybeFromWire(String? value) {
    if (value == null) {
      return null;
    }
    for (final RefType type in values) {
      if (type.wire == value) {
        return type;
      }
    }
    return null;
  }

  /// Parses [value]; falls back to [RefType.vocabulary].
  static RefType fromWire(String? value) =>
      maybeFromWire(value) ?? RefType.vocabulary;
}
