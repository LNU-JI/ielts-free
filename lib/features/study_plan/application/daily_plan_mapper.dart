/// Maps the adaptive engine's value object [DailyPlanItem] to the persisted
/// [DailyTask] model and back.
///
/// The engine (T03, docs/ARCHITECTURE-v0.1.md §5.5) is pure and knows nothing
/// about persistence. The database (T02) stores tasks with a slightly different
/// shape:
///
/// - the engine's `minutes` becomes `DailyTask.targetMinutes`;
/// - the engine's `reason` has **no column**, so it is stored inside the
///   `payload` JSON object under [reasonKey];
/// - the engine's `bucket` is kept in `payload` too, so the reverse mapping can
///   restore it without guessing.
///
/// This is the single place that knows about those differences, which keeps the
/// algorithm and the schema independent.
library;

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/core/models/daily_task.dart';
import 'package:ielts_free/core/models/enums/task_status.dart';
import 'package:ielts_free/core/models/enums/task_type.dart';
import 'package:ielts_free/core/services/adaptive/adaptive_models.dart';

/// Converts between [DailyPlanItem] and [DailyTask].
class DailyPlanMapper {
  const DailyPlanMapper();

  /// Payload key holding the human-readable allocation reason.
  static const String reasonKey = 'reason';

  /// Payload key holding the engine bucket name.
  static const String bucketKey = 'bucket';

  /// Payload key holding the engine priority (used for ordering).
  static const String priorityKey = 'priority';

  /// Maps one engine [item] to a persistable [DailyTask].
  ///
  /// [planDate] is a local `YYYY-MM-DD` string and [userId] the owning user.
  /// [sortOrder] fixes the display order within the day.
  DailyTask toDailyTask(
    DailyPlanItem item, {
    required String planDate,
    required String userId,
    required int sortOrder,
    DateTime? now,
  }) {
    final DateTime? timestamp = now?.toUtc();
    return DailyTask(
      userId: userId,
      planDate: planDate,
      taskType: item.taskType,
      skill: item.skill,
      title: titleFor(item),
      targetMinutes: item.minutes,
      itemCount: item.itemCount,
      completedCount: 0,
      status: TaskStatus.pending,
      sortOrder: sortOrder,
      payload: <String, Object?>{
        reasonKey: item.reason,
        bucketKey: item.bucket.name,
        priorityKey: item.priority,
      },
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  /// Maps a whole plan to tasks, assigning `sortOrder` by index.
  List<DailyTask> toDailyTasks(
    List<DailyPlanItem> items, {
    required String planDate,
    required String userId,
    DateTime? now,
  }) {
    final List<DailyTask> tasks = <DailyTask>[];
    for (int i = 0; i < items.length; i++) {
      tasks.add(
        toDailyTask(
          items[i],
          planDate: planDate,
          userId: userId,
          sortOrder: i,
          now: now,
        ),
      );
    }
    return List<DailyTask>.unmodifiable(tasks);
  }

  /// Reconstructs the engine value object from a stored [task] (for display).
  ///
  /// The bucket is read back from the payload when present; otherwise it is
  /// inferred from the task type. Missing numeric fields default to `0`, and a
  /// missing reason falls back to an empty string.
  DailyPlanItem fromDailyTask(DailyTask task) {
    final TaskType taskType = task.taskType ?? TaskType.vocabReview;
    return DailyPlanItem(
      bucket: _bucketFrom(task, taskType),
      taskType: taskType,
      skill: task.skill,
      minutes: task.targetMinutes ?? 0,
      itemCount: task.itemCount ?? 0,
      reason: _stringPayload(task, reasonKey) ?? '',
      priority: _doublePayload(task, priorityKey) ?? 1.0,
    );
  }

  /// A localized, human-readable title for [item] (persisted on the task).
  ///
  /// e.g. `词汇复习 20 词 · 15 min`, `阅读 1 篇 · 20 min`, `错题重做 5 题 · 10 min`.
  String titleFor(DailyPlanItem item) {
    switch (item.bucket) {
      case DailyPlanBucket.vocabulary:
        return AppStrings.taskTitle(
          AppStrings.taskTitleVocabReview,
          itemCount: item.itemCount,
          itemUnit: AppStrings.wordsUnit,
          minutes: item.minutes,
        );
      case DailyPlanBucket.reading:
        return AppStrings.taskTitle(
          AppStrings.taskTitleReading,
          itemCount: item.itemCount,
          itemUnit: AppStrings.passagesUnit,
          minutes: item.minutes,
        );
      case DailyPlanBucket.mistakes:
        return AppStrings.taskTitle(
          AppStrings.taskTitleMistakeReview,
          itemCount: item.itemCount,
          itemUnit: AppStrings.questionsUnit,
          minutes: item.minutes,
        );
    }
  }

  // --- internals ----------------------------------------------------------

  DailyPlanBucket _bucketFrom(DailyTask task, TaskType taskType) {
    final String? name = _stringPayload(task, bucketKey);
    if (name != null) {
      for (final DailyPlanBucket bucket in DailyPlanBucket.values) {
        if (bucket.name == name) {
          return bucket;
        }
      }
    }
    switch (taskType) {
      case TaskType.vocabReview:
      case TaskType.vocabPractice:
        return DailyPlanBucket.vocabulary;
      case TaskType.reading:
        return DailyPlanBucket.reading;
      case TaskType.mistakeReview:
        return DailyPlanBucket.mistakes;
    }
  }

  String? _stringPayload(DailyTask task, String key) {
    final Object? value = task.payload[key];
    return value is String ? value : null;
  }

  double? _doublePayload(DailyTask task, String key) {
    final Object? value = task.payload[key];
    return value is num ? value.toDouble() : null;
  }
}
