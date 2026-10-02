/// Learning session (learning_sessions table).
///
/// Supports crash recovery + autosave: [checkpoint] persists enough state to
/// resume after the app is killed (docs/BRIEF.md §79).
library;

import 'package:ielts_free/core/models/enums/ref_type.dart';
import 'package:ielts_free/core/models/enums/session_status.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// One learning session (a run through vocabulary or reading).
class LearningSession {
  const LearningSession({
    required this.id,
    this.userId,
    this.sessionType,
    this.startedAt,
    this.endedAt,
    this.durationSec,
    this.itemsCompleted,
    this.checkpoint = const <String, Object?>{},
    this.status = SessionStatus.active,
  });

  /// `learning_sessions.id` (UUID).
  final String id;

  /// Owning user id.
  final String? userId;

  /// What kind of session this is.
  final RefType? sessionType;

  /// Start timestamp (UTC).
  final DateTime? startedAt;

  /// End timestamp (UTC).
  final DateTime? endedAt;

  /// Duration in seconds.
  final int? durationSec;

  /// Number of items completed.
  final int? itemsCompleted;

  /// Resume payload (JSON object).
  final Map<String, Object?> checkpoint;

  /// Lifecycle status.
  final SessionStatus status;

  /// Returns a copy with the given fields replaced.
  LearningSession copyWith({
    DateTime? endedAt,
    int? durationSec,
    int? itemsCompleted,
    Map<String, Object?>? checkpoint,
    SessionStatus? status,
  }) =>
      LearningSession(
        id: id,
        userId: userId,
        sessionType: sessionType,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        durationSec: durationSec ?? this.durationSec,
        itemsCompleted: itemsCompleted ?? this.itemsCompleted,
        checkpoint: checkpoint ?? this.checkpoint,
        status: status ?? this.status,
      );

  /// Builds a [LearningSession] from a database row / JSON object.
  factory LearningSession.fromMap(Map<String, Object?> map) => LearningSession(
        id: asString(map['id']) ?? '',
        userId: asString(map['user_id']),
        sessionType: RefType.maybeFromWire(asString(map['session_type'])),
        startedAt: AppDateUtils.parseUtcIso(asString(map['started_at'])),
        endedAt: AppDateUtils.parseUtcIso(asString(map['ended_at'])),
        durationSec: asInt(map['duration_sec']),
        itemsCompleted: asInt(map['items_completed']),
        checkpoint: decodeMap(map['checkpoint']) ?? const <String, Object?>{},
        status: SessionStatus.fromWire(asString(map['status'])),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'user_id': userId,
        'session_type': sessionType?.wire,
        'started_at':
            startedAt == null ? null : AppDateUtils.toUtcIso(startedAt!),
        'ended_at': endedAt == null ? null : AppDateUtils.toUtcIso(endedAt!),
        'duration_sec': durationSec,
        'items_completed': itemsCompleted,
        'checkpoint': encodeMap(checkpoint),
        'status': status.wire,
      };
}
