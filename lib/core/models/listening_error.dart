/// A listening mistake (listening_error_log table).
///
/// One row per missed answer in the intensive-listening loop. Recording the
/// **cause** ([errorType]) rather than just "wrong" is what turns a section
/// into a repeatable drill (lib/core/database/migrations.dart, step 3).
library;

import 'package:ielts_free/core/models/enums/listening_error_type.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// One classified listening error.
class ListeningError {
  const ListeningError({
    this.id,
    required this.userId,
    required this.sectionId,
    this.questionId,
    this.cueId,
    required this.errorType,
    required this.createdAt,
  });

  /// `listening_error_log.id`.
  final int? id;

  /// Owning user id (NOT NULL).
  final String userId;

  /// The section that was being practised (NOT NULL).
  final int sectionId;

  /// The question that was missed, when the error came from a question.
  final int? questionId;

  /// The cue (sentence) that caused the error, when known.
  final int? cueId;

  /// The classified cause of the miss.
  final ListeningErrorType errorType;

  /// When the error was logged (UTC).
  final DateTime createdAt;

  /// Builds a [ListeningError] from a database row / JSON object.
  factory ListeningError.fromMap(Map<String, Object?> map) => ListeningError(
        id: asInt(map['id']),
        userId: asString(map['user_id']) ?? '',
        sectionId: intOrDefault(map['section_id'], 0),
        questionId: asInt(map['question_id']),
        cueId: asInt(map['cue_id']),
        errorType: ListeningErrorType.fromWire(asString(map['error_type'])),
        createdAt: AppDateUtils.parseUtcIso(asString(map['created_at'])) ??
            DateTime.now().toUtc(),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'section_id': sectionId,
        'question_id': questionId,
        'cue_id': cueId,
        'error_type': errorType.wire,
        'created_at': AppDateUtils.toUtcIso(createdAt),
      };
}
