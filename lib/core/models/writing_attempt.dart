/// A recorded writing attempt (writing_attempts table).
///
/// One row per timed attempt. The essay body is stored locally as plain text;
/// [wordCount] is denormalised so statistics never re-count the text
/// (lib/core/database/migrations.dart, step 3).
library;

import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// One writing practice attempt.
class WritingAttempt {
  const WritingAttempt({
    this.id,
    required this.userId,
    required this.taskId,
    required this.taskNumber,
    required this.content,
    this.wordCount = 0,
    this.durationSec = 0,
    this.selfRating,
    required this.createdAt,
  });

  /// `writing_attempts.id`.
  final int? id;

  /// Owning user id (NOT NULL).
  final String userId;

  /// The task that was written (NOT NULL).
  final int taskId;

  /// Task number: 1 or 2 (NOT NULL).
  final int taskNumber;

  /// The essay body.
  final String content;

  /// Word count of [content].
  final int wordCount;

  /// How long the learner wrote, in seconds.
  final int durationSec;

  /// Self-assessed rating, e.g. `good` / `needs work`.
  final String? selfRating;

  /// When the attempt was recorded (UTC).
  final DateTime createdAt;

  /// Builds a [WritingAttempt] from a database row / JSON object.
  factory WritingAttempt.fromMap(Map<String, Object?> map) => WritingAttempt(
        id: asInt(map['id']),
        userId: asString(map['user_id']) ?? '',
        taskId: intOrDefault(map['task_id'], 0),
        taskNumber: intOrDefault(map['task_number'], 0),
        content: asString(map['content']) ?? '',
        wordCount: intOrDefault(map['word_count'], 0),
        durationSec: intOrDefault(map['duration_sec'], 0),
        selfRating: asString(map['self_rating']),
        createdAt: AppDateUtils.parseUtcIso(asString(map['created_at'])) ??
            DateTime.now().toUtc(),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'task_id': taskId,
        'task_number': taskNumber,
        'content': content,
        'word_count': wordCount,
        'duration_sec': durationSec,
        'self_rating': selfRating,
        'created_at': AppDateUtils.toUtcIso(createdAt),
      };
}
