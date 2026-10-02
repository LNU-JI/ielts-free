/// A mistake (mistakes table).
///
/// Every wrong answer creates (or bumps) a mistake row (docs/BRIEF.md §28,
/// ARCHITECTURE §4.3). [status] is derived from [mastery], not stored.
library;

import 'package:ielts_free/core/models/enums/error_type.dart';
import 'package:ielts_free/core/models/enums/mistake_status.dart';
import 'package:ielts_free/core/models/enums/question_type.dart';
import 'package:ielts_free/core/models/enums/ref_type.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// One mistake the user made.
class Mistake {
  const Mistake({
    this.id,
    this.userId,
    this.refType,
    this.refId,
    this.questionType,
    this.skill,
    this.userAnswer,
    this.correctAnswer,
    this.errorType,
    this.difficulty,
    this.wrongCount = 1,
    this.lastWrongAt,
    this.mastery = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  /// `mistakes.id`.
  final int? id;

  /// Owning user id.
  final String? userId;

  /// Whether the mistake refers to a word or a reading question.
  final RefType? refType;

  /// The referenced item id.
  final int? refId;

  /// The question format (for reading mistakes).
  final QuestionType? questionType;

  /// The skill exercised.
  final SkillType? skill;

  /// What the user answered.
  final String? userAnswer;

  /// The correct answer.
  final String? correctAnswer;

  /// The classified error type (BRIEF §29).
  final ErrorType? errorType;

  /// Difficulty of the item.
  final int? difficulty;

  /// How many times the item has been answered wrongly.
  final int wrongCount;

  /// When it was last answered wrongly (UTC).
  final DateTime? lastWrongAt;

  /// Mastery in `[0, 1]`; rises as the item is redone correctly.
  final double mastery;

  /// Creation timestamp (UTC).
  final DateTime? createdAt;

  /// Last-update timestamp (UTC).
  final DateTime? updatedAt;

  /// Derived status from [mastery] (ARCHITECTURE §5.7).
  MistakeStatus get status => mastery >= MistakeStatus.masteryThreshold
      ? MistakeStatus.mastered
      : MistakeStatus.active;

  /// Whether the item has been mastered and can fade from the active queue.
  bool get isMastered => status == MistakeStatus.mastered;

  /// Builds a [Mistake] from a database row / JSON object.
  factory Mistake.fromMap(Map<String, Object?> map) => Mistake(
        id: asInt(map['id']),
        userId: asString(map['user_id']),
        refType: RefType.maybeFromWire(asString(map['ref_type'])),
        refId: asInt(map['ref_id']),
        questionType: QuestionType.maybeFromWire(asString(map['question_type'])),
        skill: SkillType.maybeFromWire(asString(map['skill'])),
        userAnswer: asString(map['user_answer']),
        correctAnswer: asString(map['correct_answer']),
        errorType: ErrorType.maybeFromWire(asString(map['error_type'])),
        difficulty: asInt(map['difficulty']),
        wrongCount: intOrDefault(map['wrong_count'], 1),
        lastWrongAt: AppDateUtils.parseUtcIso(asString(map['last_wrong_at'])),
        mastery: doubleOrDefault(map['mastery'], 0),
        createdAt: AppDateUtils.parseUtcIso(asString(map['created_at'])),
        updatedAt: AppDateUtils.parseUtcIso(asString(map['updated_at'])),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'ref_type': refType?.wire,
        'ref_id': refId,
        'question_type': questionType?.wire,
        'skill': skill?.wire,
        'user_answer': userAnswer,
        'correct_answer': correctAnswer,
        'error_type': errorType?.wire,
        'difficulty': difficulty,
        'wrong_count': wrongCount,
        'last_wrong_at':
            lastWrongAt == null ? null : AppDateUtils.toUtcIso(lastWrongAt!),
        'mastery': mastery,
        'created_at':
            createdAt == null ? null : AppDateUtils.toUtcIso(createdAt!),
        'updated_at':
            updatedAt == null ? null : AppDateUtils.toUtcIso(updatedAt!),
      };
}
