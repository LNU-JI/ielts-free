/// Study plan day (study_plan table).
///
/// A lightweight per-day summary; the authoritative work items live in
/// `daily_tasks` and are recomputed daily (docs/BRIEF.md §36).
library;

import 'package:ielts_free/core/models/enums/plan_phase.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// A single day entry of a study plan.
class StudyPlan {
  const StudyPlan({
    this.id,
    this.userId,
    this.goalId,
    this.dayIndex,
    this.planDate,
    this.phase,
    this.summary = const <String, Object?>{},
    this.createdAt,
  });

  /// `study_plan.id`.
  final int? id;

  /// Owning user id.
  final String? userId;

  /// Owning goal id.
  final int? goalId;

  /// 1-based index of the day within the plan.
  final int? dayIndex;

  /// The day's date (`YYYY-MM-DD`, local).
  final String? planDate;

  /// Phase this day belongs to.
  final PlanPhase? phase;

  /// Free-form summary payload (JSON object).
  final Map<String, Object?> summary;

  /// Creation timestamp (UTC).
  final DateTime? createdAt;

  /// Builds a [StudyPlan] from a database row / JSON object.
  factory StudyPlan.fromMap(Map<String, Object?> map) => StudyPlan(
        id: asInt(map['id']),
        userId: asString(map['user_id']),
        goalId: asInt(map['goal_id']),
        dayIndex: asInt(map['day_index']),
        planDate: asString(map['plan_date']),
        phase: map['phase'] == null
            ? null
            : PlanPhase.fromWire(asString(map['phase'])),
        summary: decodeMap(map['summary']) ?? const <String, Object?>{},
        createdAt: AppDateUtils.parseUtcIso(asString(map['created_at'])),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'goal_id': goalId,
        'day_index': dayIndex,
        'plan_date': planDate,
        'phase': phase?.wire,
        'summary': encodeMap(summary),
        'created_at':
            createdAt == null ? null : AppDateUtils.toUtcIso(createdAt!),
      };
}
