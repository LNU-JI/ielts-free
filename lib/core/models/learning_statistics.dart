/// Learning statistics (learning_statistics table).
///
/// Per-day aggregate plus running totals and the current streak
/// (docs/BRIEF.md §37, ARCHITECTURE §4.3). One row per `(user, stat_date)`.
library;

import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// Aggregated statistics for one day (and running totals).
class LearningStatistics {
  const LearningStatistics({
    this.id,
    this.userId,
    this.statDate,
    this.studyMinutes = 0,
    this.questionsAnswered = 0,
    this.correctCount = 0,
    this.wordsReviewed = 0,
    this.wordsMastered = 0,
    this.currentStreak = 0,
    this.lastStudyDate,
    this.totalStudyMinutes = 0,
    this.totalDays = 0,
    this.updatedAt,
  });

  /// `learning_statistics.id`.
  final int? id;

  /// Owning user id.
  final String? userId;

  /// The day these figures describe (`YYYY-MM-DD`, local).
  final String? statDate;

  /// Minutes studied that day.
  final int studyMinutes;

  /// Questions answered that day.
  final int questionsAnswered;

  /// Correct answers that day.
  final int correctCount;

  /// Words reviewed that day.
  final int wordsReviewed;

  /// Words mastered that day.
  final int wordsMastered;

  /// Streak length as of that day.
  final int currentStreak;

  /// The most recent day the user studied (`YYYY-MM-DD`).
  final String? lastStudyDate;

  /// Lifetime study minutes.
  final int totalStudyMinutes;

  /// Lifetime distinct study days.
  final int totalDays;

  /// Last-update timestamp (UTC).
  final DateTime? updatedAt;

  /// Accuracy for the day in `[0, 1]` (0 when nothing answered).
  double get accuracy =>
      questionsAnswered <= 0 ? 0 : correctCount / questionsAnswered;

  /// Builds a [LearningStatistics] from a database row / JSON object.
  factory LearningStatistics.fromMap(Map<String, Object?> map) =>
      LearningStatistics(
        id: asInt(map['id']),
        userId: asString(map['user_id']),
        statDate: asString(map['stat_date']),
        studyMinutes: intOrDefault(map['study_minutes'], 0),
        questionsAnswered: intOrDefault(map['questions_answered'], 0),
        correctCount: intOrDefault(map['correct_count'], 0),
        wordsReviewed: intOrDefault(map['words_reviewed'], 0),
        wordsMastered: intOrDefault(map['words_mastered'], 0),
        currentStreak: intOrDefault(map['current_streak'], 0),
        lastStudyDate: asString(map['last_study_date']),
        totalStudyMinutes: intOrDefault(map['total_study_minutes'], 0),
        totalDays: intOrDefault(map['total_days'], 0),
        updatedAt: AppDateUtils.parseUtcIso(asString(map['updated_at'])),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'stat_date': statDate,
        'study_minutes': studyMinutes,
        'questions_answered': questionsAnswered,
        'correct_count': correctCount,
        'words_reviewed': wordsReviewed,
        'words_mastered': wordsMastered,
        'current_streak': currentStreak,
        'last_study_date': lastStudyDate,
        'total_study_minutes': totalStudyMinutes,
        'total_days': totalDays,
        'updated_at':
            updatedAt == null ? null : AppDateUtils.toUtcIso(updatedAt!),
      };
}
