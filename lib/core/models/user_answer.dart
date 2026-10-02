/// A recorded answer (user_answers table).
///
/// Every submitted answer is stored here; wrong answers additionally create a
/// `mistakes` row (docs/BRIEF.md §28/§77, ARCHITECTURE §4.3).
library;

import 'package:ielts_free/core/models/enums/ref_type.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// One answer event.
class UserAnswer {
  const UserAnswer({
    this.id,
    this.userId,
    this.refType,
    this.refId,
    this.skill,
    this.userAnswer,
    this.isCorrect = false,
    this.difficulty,
    this.timeSpentMs,
    this.sessionId,
    required this.answeredAt,
  });

  /// `user_answers.id`.
  final int? id;

  /// Owning user id.
  final String? userId;

  /// What was answered (a word or a question).
  final RefType? refType;

  /// The referenced item id.
  final int? refId;

  /// The skill exercised.
  final SkillType? skill;

  /// The raw answer the user gave.
  final String? userAnswer;

  /// Whether it was correct.
  final bool isCorrect;

  /// Difficulty of the item.
  final int? difficulty;

  /// Time spent on the item, in milliseconds.
  final int? timeSpentMs;

  /// Owning session id.
  final String? sessionId;

  /// When the answer was submitted (UTC).
  final DateTime answeredAt;

  /// Builds a [UserAnswer] from a database row / JSON object.
  factory UserAnswer.fromMap(Map<String, Object?> map) => UserAnswer(
        id: asInt(map['id']),
        userId: asString(map['user_id']),
        refType: RefType.maybeFromWire(asString(map['ref_type'])),
        refId: asInt(map['ref_id']),
        skill: SkillType.maybeFromWire(asString(map['skill'])),
        userAnswer: asString(map['user_answer']),
        isCorrect: asBool(map['is_correct']),
        difficulty: asInt(map['difficulty']),
        timeSpentMs: asInt(map['time_spent_ms']),
        sessionId: asString(map['session_id']),
        answeredAt: AppDateUtils.parseUtcIso(asString(map['answered_at'])) ??
            DateTime.now().toUtc(),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'ref_type': refType?.wire,
        'ref_id': refId,
        'skill': skill?.wire,
        'user_answer': userAnswer,
        'is_correct': isCorrect ? 1 : 0,
        'difficulty': difficulty,
        'time_spent_ms': timeSpentMs,
        'session_id': sessionId,
        'answered_at': AppDateUtils.toUtcIso(answeredAt),
      };
}
