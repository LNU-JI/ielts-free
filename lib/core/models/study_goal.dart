/// Study goal (study_goal table).
///
/// Target band, exam date, daily study time and the active plan window
/// (docs/BRIEF.md §11/§42, ARCHITECTURE §4.3).
library;

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/models/enums/plan_type.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// A study-goal row.
class StudyGoal {
  const StudyGoal({
    this.id,
    required this.userId,
    this.targetBand = AppConstants.defaultTargetBand,
    this.examDate,
    this.dailyStudyMinutes = AppConstants.defaultDailyStudyMinutes,
    this.planType,
    this.planStartDate,
    this.planEndDate,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// `study_goal.id`.
  final int? id;

  /// Owning user id.
  final String userId;

  /// Target band score (e.g. `7.0`).
  final double targetBand;

  /// Exam date as a LOCAL `YYYY-MM-DD` string, or `null` when undecided.
  final String? examDate;

  /// Daily study budget in minutes.
  final int dailyStudyMinutes;

  /// Selected plan length.
  final PlanType? planType;

  /// Plan start date (`YYYY-MM-DD`).
  final String? planStartDate;

  /// Plan end date (`YYYY-MM-DD`).
  final String? planEndDate;

  /// Whether this is the active goal for the user.
  final bool isActive;

  /// Creation timestamp (UTC).
  final DateTime? createdAt;

  /// Last-update timestamp (UTC).
  final DateTime? updatedAt;

  /// The default goal for the guest user (BRIEF §11).
  factory StudyGoal.localDefault({DateTime? now}) {
    final DateTime timestamp = (now ?? DateTime.now()).toUtc();
    return StudyGoal(
      userId: AppConstants.localUserId,
      targetBand: AppConstants.defaultTargetBand,
      examDate: AppConstants.defaultExamDate,
      dailyStudyMinutes: AppConstants.defaultDailyStudyMinutes,
      planType: PlanType.day30,
      isActive: true,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  /// Days left until the exam (local calendar), or `null` when unset.
  int? get daysRemaining {
    final String? date = examDate;
    if (date == null || date.isEmpty) {
      return null;
    }
    return AppDateUtils.daysBetweenLocalDates(
      DateTime.now(),
      AppDateUtils.parseLocalDate(date),
    );
  }

  /// Builds a [StudyGoal] from a database row / JSON object.
  factory StudyGoal.fromMap(Map<String, Object?> map) => StudyGoal(
        id: asInt(map['id']),
        userId: asString(map['user_id']) ?? AppConstants.localUserId,
        targetBand:
            doubleOrDefault(map['target_band'], AppConstants.defaultTargetBand),
        examDate: asString(map['exam_date']),
        dailyStudyMinutes: intOrDefault(
            map['daily_study_minutes'], AppConstants.defaultDailyStudyMinutes),
        planType: map['plan_type'] == null
            ? null
            : PlanType.fromWire(asString(map['plan_type'])),
        planStartDate: asString(map['plan_start_date']),
        planEndDate: asString(map['plan_end_date']),
        isActive: asBool(map['is_active'], fallback: true),
        createdAt: AppDateUtils.parseUtcIso(asString(map['created_at'])),
        updatedAt: AppDateUtils.parseUtcIso(asString(map['updated_at'])),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'target_band': targetBand,
        'exam_date': examDate,
        'daily_study_minutes': dailyStudyMinutes,
        'plan_type': planType?.wire,
        'plan_start_date': planStartDate,
        'plan_end_date': planEndDate,
        'is_active': isActive ? 1 : 0,
        'created_at':
            createdAt == null ? null : AppDateUtils.toUtcIso(createdAt!),
        'updated_at':
            updatedAt == null ? null : AppDateUtils.toUtcIso(updatedAt!),
      };
}
