/// Vocabulary memory state (vocabulary_reviews table).
///
/// Tracks the spaced-repetition level, counters and the next review time for one
/// vocabulary item (docs/BRIEF.md §15, ARCHITECTURE §4.3).
library;

import 'package:ielts_free/core/models/enums/memory_level.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// The user-specific review state of a vocabulary item.
class VocabularyReview {
  const VocabularyReview({
    this.id,
    this.userId,
    required this.vocabularyId,
    this.memoryLevel = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.streak = 0,
    this.lastReviewedAt,
    this.nextReviewAt,
    this.isMastered = false,
    this.isFavorite = false,
    this.createdAt,
    this.updatedAt,
  });

  /// `vocabulary_reviews.id`.
  final int? id;

  /// Owning user id.
  final String? userId;

  /// The vocabulary id this state belongs to.
  final int vocabularyId;

  /// Memory level 0..6.
  final int memoryLevel;

  /// Total correct answers.
  final int correctCount;

  /// Total wrong answers.
  final int wrongCount;

  /// Current correct-answer streak.
  final int streak;

  /// Last review timestamp (UTC).
  final DateTime? lastReviewedAt;

  /// Next scheduled review timestamp (UTC).
  final DateTime? nextReviewAt;

  /// Whether the word is considered mastered.
  final bool isMastered;

  /// Whether the word is favourited.
  final bool isFavorite;

  /// Creation timestamp (UTC).
  final DateTime? createdAt;

  /// Last-update timestamp (UTC).
  final DateTime? updatedAt;

  /// The memory level as an enum.
  MemoryLevel get level => MemoryLevel.fromValue(memoryLevel);

  /// Whether the word is due for review now.
  bool get isDue {
    final DateTime? next = nextReviewAt;
    if (next == null) {
      return true;
    }
    return !next.isAfter(DateTime.now().toUtc());
  }

  /// Returns a copy with the given fields replaced.
  VocabularyReview copyWith({
    int? memoryLevel,
    int? correctCount,
    int? wrongCount,
    int? streak,
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
    bool? isMastered,
    bool? isFavorite,
    DateTime? updatedAt,
  }) =>
      VocabularyReview(
        id: id,
        userId: userId,
        vocabularyId: vocabularyId,
        memoryLevel: memoryLevel ?? this.memoryLevel,
        correctCount: correctCount ?? this.correctCount,
        wrongCount: wrongCount ?? this.wrongCount,
        streak: streak ?? this.streak,
        lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
        nextReviewAt: nextReviewAt ?? this.nextReviewAt,
        isMastered: isMastered ?? this.isMastered,
        isFavorite: isFavorite ?? this.isFavorite,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Builds a [VocabularyReview] from a database row / JSON object.
  factory VocabularyReview.fromMap(Map<String, Object?> map) => VocabularyReview(
        id: asInt(map['id']),
        userId: asString(map['user_id']),
        vocabularyId: intOrDefault(map['vocabulary_id'], 0),
        memoryLevel: intOrDefault(map['memory_level'], 0),
        correctCount: intOrDefault(map['correct_count'], 0),
        wrongCount: intOrDefault(map['wrong_count'], 0),
        streak: intOrDefault(map['streak'], 0),
        lastReviewedAt:
            AppDateUtils.parseUtcIso(asString(map['last_reviewed_at'])),
        nextReviewAt: AppDateUtils.parseUtcIso(asString(map['next_review_at'])),
        isMastered: asBool(map['is_mastered']),
        isFavorite: asBool(map['is_favorite']),
        createdAt: AppDateUtils.parseUtcIso(asString(map['created_at'])),
        updatedAt: AppDateUtils.parseUtcIso(asString(map['updated_at'])),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'vocabulary_id': vocabularyId,
        'memory_level': memoryLevel,
        'correct_count': correctCount,
        'wrong_count': wrongCount,
        'streak': streak,
        'last_reviewed_at': lastReviewedAt == null
            ? null
            : AppDateUtils.toUtcIso(lastReviewedAt!),
        'next_review_at':
            nextReviewAt == null ? null : AppDateUtils.toUtcIso(nextReviewAt!),
        'is_mastered': isMastered ? 1 : 0,
        'is_favorite': isFavorite ? 1 : 0,
        'created_at':
            createdAt == null ? null : AppDateUtils.toUtcIso(createdAt!),
        'updated_at':
            updatedAt == null ? null : AppDateUtils.toUtcIso(updatedAt!),
      };
}
