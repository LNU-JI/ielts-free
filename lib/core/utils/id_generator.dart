/// Identifier generation.
///
/// Session and answer identifiers are UUID v4 values; a monotonic-ish
/// timestamp identifier is offered for debugging / ordering helpers.
library;

import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// Factory helpers for unique identifiers.
abstract final class IdGenerator {
  /// A fresh random UUID v4 string.
  static String newId() => _uuid.v4();

  /// A UUID for a new learning session (`learning_sessions.id`).
  static String newSessionId() => _uuid.v4();

  /// A UUID for a new answer row, useful when an explicit id is required.
  static String newAnswerId() => _uuid.v4();

  /// Milliseconds-since-epoch string, handy for deterministic ordering in
  /// diagnostics. Not guaranteed unique under rapid calls.
  static String timestampId() =>
      DateTime.now().toUtc().microsecondsSinceEpoch.toString();
}
