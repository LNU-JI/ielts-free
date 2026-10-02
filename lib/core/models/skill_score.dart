/// Skill score (skill_scores table).
///
/// The five-dimension ability model plus reading sub-dimensions
/// (docs/BRIEF.md §30/§31, ARCHITECTURE §4.3). One row per `(user, skill)`.
library;

import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// The adaptive score for one skill.
class SkillScore {
  const SkillScore({
    this.id,
    this.userId,
    required this.skill,
    this.score = 0.0,
    this.currentDifficulty = 2,
    this.sampleCount = 0,
    this.lastPracticedAt,
    this.updatedAt,
  });

  /// `skill_scores.id`.
  final int? id;

  /// Owning user id.
  final String? userId;

  /// The skill this score describes.
  final SkillType skill;

  /// Normalised score in `[0, 100]`.
  final double score;

  /// Current adaptive difficulty 1..5.
  final int currentDifficulty;

  /// Number of answers folded into this score.
  final int sampleCount;

  /// Last practice timestamp (UTC).
  final DateTime? lastPracticedAt;

  /// Last-update timestamp (UTC).
  final DateTime? updatedAt;

  /// Returns a copy with the given fields replaced.
  SkillScore copyWith({
    double? score,
    int? currentDifficulty,
    int? sampleCount,
    DateTime? lastPracticedAt,
    DateTime? updatedAt,
  }) =>
      SkillScore(
        id: id,
        userId: userId,
        skill: skill,
        score: score ?? this.score,
        currentDifficulty: currentDifficulty ?? this.currentDifficulty,
        sampleCount: sampleCount ?? this.sampleCount,
        lastPracticedAt: lastPracticedAt ?? this.lastPracticedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Builds a [SkillScore] from a database row / JSON object.
  factory SkillScore.fromMap(Map<String, Object?> map) => SkillScore(
        id: asInt(map['id']),
        userId: asString(map['user_id']),
        skill: SkillType.fromWire(asString(map['skill'])),
        score: doubleOrDefault(map['score'], 0),
        currentDifficulty: intOrDefault(map['current_difficulty'], 2),
        sampleCount: intOrDefault(map['sample_count'], 0),
        lastPracticedAt:
            AppDateUtils.parseUtcIso(asString(map['last_practiced_at'])),
        updatedAt: AppDateUtils.parseUtcIso(asString(map['updated_at'])),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'skill': skill.wire,
        'score': score,
        'current_difficulty': currentDifficulty,
        'sample_count': sampleCount,
        'last_practiced_at': lastPracticedAt == null
            ? null
            : AppDateUtils.toUtcIso(lastPracticedAt!),
        'updated_at':
            updatedAt == null ? null : AppDateUtils.toUtcIso(updatedAt!),
      };
}
