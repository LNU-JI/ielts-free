/// A recorded speaking attempt (speaking_attempts table).
///
/// One row per timed practice run. Audio stays on device ([audioPath] is a local
/// file path) — nothing is uploaded (lib/core/database/migrations.dart, step 3).
library;

import 'package:ielts_free/core/models/enums/speaking_part.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// One speaking practice attempt.
class SpeakingAttempt {
  const SpeakingAttempt({
    this.id,
    required this.userId,
    required this.questionId,
    required this.topicId,
    required this.part,
    this.durationSec = 0,
    this.audioPath,
    this.selfRating,
    required this.createdAt,
  });

  /// `speaking_attempts.id`.
  final int? id;

  /// Owning user id (NOT NULL).
  final String userId;

  /// The question that was answered (NOT NULL).
  final int questionId;

  /// The owning topic (NOT NULL).
  final int topicId;

  /// Which part of the test (NOT NULL).
  final SpeakingPart part;

  /// How long the learner spoke, in seconds.
  final int durationSec;

  /// Local file path of the recording, when one was kept.
  final String? audioPath;

  /// Self-assessed rating, e.g. `good` / `needs work`.
  final String? selfRating;

  /// When the attempt was recorded (UTC).
  final DateTime createdAt;

  /// Whether a recording was kept.
  bool get hasAudio => audioPath != null && audioPath!.isNotEmpty;

  /// Builds a [SpeakingAttempt] from a database row / JSON object.
  factory SpeakingAttempt.fromMap(Map<String, Object?> map) => SpeakingAttempt(
        id: asInt(map['id']),
        userId: asString(map['user_id']) ?? '',
        questionId: intOrDefault(map['question_id'], 0),
        topicId: intOrDefault(map['topic_id'], 0),
        part: SpeakingPart.fromWire(asInt(map['part'])),
        durationSec: intOrDefault(map['duration_sec'], 0),
        audioPath: asString(map['audio_path']),
        selfRating: asString(map['self_rating']),
        createdAt: AppDateUtils.parseUtcIso(asString(map['created_at'])) ??
            DateTime.now().toUtc(),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'question_id': questionId,
        'topic_id': topicId,
        'part': part.wire,
        'duration_sec': durationSec,
        'audio_path': audioPath,
        'self_rating': selfRating,
        'created_at': AppDateUtils.toUtcIso(createdAt),
      };
}
