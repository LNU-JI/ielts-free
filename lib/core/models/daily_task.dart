/// Daily task (daily_tasks table).
///
/// The output of the daily-plan algorithm (docs/BRIEF.md §34). `payload` holds
/// algorithm-specific data (e.g. the ids of the words to review).
library;

import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/enums/task_status.dart';
import 'package:ielts_free/core/models/enums/task_type.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// A single task in a day's plan.
class DailyTask {
  const DailyTask({
    this.id,
    this.userId,
    required this.planDate,
    this.taskType,
    this.skill,
    this.title,
    this.targetMinutes,
    this.itemCount,
    this.completedCount = 0,
    this.status = TaskStatus.pending,
    this.sortOrder,
    this.payload = const <String, Object?>{},
    this.createdAt,
    this.updatedAt,
  });

  /// `daily_tasks.id`.
  final int? id;

  /// Owning user id.
  final String? userId;

  /// The day this task belongs to (`YYYY-MM-DD`, local).
  final String planDate;

  /// Kind of task.
  final TaskType? taskType;

  /// Skill this task trains.
  final SkillType? skill;

  /// Human-readable title.
  final String? title;

  /// Target duration in minutes.
  final int? targetMinutes;

  /// Number of items (words / questions).
  final int? itemCount;

  /// Items already completed.
  final int completedCount;

  /// Completion status.
  final TaskStatus status;

  /// Display order within the day.
  final int? sortOrder;

  /// Algorithm payload (JSON object).
  final Map<String, Object?> payload;

  /// Creation timestamp (UTC).
  final DateTime? createdAt;

  /// Last-update timestamp (UTC).
  final DateTime? updatedAt;

  /// Fraction complete in `[0, 1]`.
  double get progress {
    final int? total = itemCount;
    if (total == null || total <= 0) {
      return status.isDone ? 1 : 0;
    }
    final double ratio = completedCount / total;
    return ratio.clamp(0, 1).toDouble();
  }

  /// Returns a copy with the given fields replaced.
  DailyTask copyWith({
    int? completedCount,
    TaskStatus? status,
    int? sortOrder,
    DateTime? updatedAt,
  }) =>
      DailyTask(
        id: id,
        userId: userId,
        planDate: planDate,
        taskType: taskType,
        skill: skill,
        title: title,
        targetMinutes: targetMinutes,
        itemCount: itemCount,
        completedCount: completedCount ?? this.completedCount,
        status: status ?? this.status,
        sortOrder: sortOrder ?? this.sortOrder,
        payload: payload,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Builds a [DailyTask] from a database row / JSON object.
  factory DailyTask.fromMap(Map<String, Object?> map) => DailyTask(
        id: asInt(map['id']),
        userId: asString(map['user_id']),
        planDate: asString(map['plan_date']) ??
            AppDateUtils.todayLocalDateString(),
        taskType: TaskType.maybeFromWire(asString(map['task_type'])),
        skill: SkillType.maybeFromWire(asString(map['skill'])),
        title: asString(map['title']),
        targetMinutes: asInt(map['target_minutes']),
        itemCount: asInt(map['item_count']),
        completedCount: intOrDefault(map['completed_count'], 0),
        status: TaskStatus.fromWire(asString(map['status'])),
        sortOrder: asInt(map['sort_order']),
        payload: decodeMap(map['payload']) ?? const <String, Object?>{},
        createdAt: AppDateUtils.parseUtcIso(asString(map['created_at'])),
        updatedAt: AppDateUtils.parseUtcIso(asString(map['updated_at'])),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'plan_date': planDate,
        'task_type': taskType?.wire,
        'skill': skill?.wire,
        'title': title,
        'target_minutes': targetMinutes,
        'item_count': itemCount,
        'completed_count': completedCount,
        'status': status.wire,
        'sort_order': sortOrder,
        'payload': encodeMap(payload),
        'created_at':
            createdAt == null ? null : AppDateUtils.toUtcIso(createdAt!),
        'updated_at':
            updatedAt == null ? null : AppDateUtils.toUtcIso(updatedAt!),
      };
}
