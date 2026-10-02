/// Plan repository — daily tasks and study-plan days.
library;

import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/daily_task.dart';
import 'package:ielts_free/core/models/enums/plan_phase.dart';
import 'package:ielts_free/core/models/enums/task_status.dart';
import 'package:ielts_free/core/models/study_plan.dart';
import 'package:ielts_free/core/storage/dao/user/daily_task_dao.dart';
import 'package:ielts_free/core/storage/dao/user/study_plan_dao.dart';
import 'package:ielts_free/core/storage/paging.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// Read/write access to the daily plan and the study plan.
abstract interface class PlanRepository {
  /// Today's tasks for [userId] (local date when [planDate] is omitted).
  Future<List<DailyTask>> tasksForDate(String userId, {String? planDate});

  /// Replaces the tasks of a day atomically.
  Future<void> replaceTasks(
    String userId,
    String planDate,
    List<DailyTask> tasks,
  );

  /// Updates one task's progress.
  Future<void> updateTaskProgress(
    int taskId, {
    required int completedCount,
    required TaskStatus status,
  });

  /// Average completion ratio of a day's tasks, in `[0, 1]`.
  Future<double> completionRatio(String userId, {String? planDate});

  /// A page of study-plan days.
  Future<PagedList<StudyPlan>> planDays(
    String userId, {
    int page = 1,
    int pageSize = 30,
  });

  /// Inserts many plan days.
  Future<void> savePlanDays(List<StudyPlan> plans);

  /// Deletes every plan day for [userId].
  Future<void> clearPlanDays(String userId);

  /// The current study phase derived from the exam countdown.
  Future<PlanPhase> currentPhase(String userId, {int? daysRemaining});
}

/// SQLite-backed [PlanRepository].
class SqlitePlanRepository implements PlanRepository {
  SqlitePlanRepository(this._taskDao, this._planDao);

  final DailyTaskDao _taskDao;
  final StudyPlanDao _planDao;

  @override
  Future<List<DailyTask>> tasksForDate(String userId, {String? planDate}) =>
      runDbGuarded(
        'PLAN_TASKS',
        () => _taskDao.forDate(
          userId,
          planDate ?? AppDateUtils.todayLocalDateString(),
        ),
      );

  @override
  Future<void> replaceTasks(
    String userId,
    String planDate,
    List<DailyTask> tasks,
  ) =>
      runDbGuarded(
        'PLAN_REPLACE_TASKS',
        () => _taskDao.replaceForDate(userId, planDate, tasks),
      );

  @override
  Future<void> updateTaskProgress(
    int taskId, {
    required int completedCount,
    required TaskStatus status,
  }) =>
      runDbGuarded(
        'PLAN_TASK_PROGRESS',
        () => _taskDao.updateProgress(
          taskId,
          completedCount: completedCount,
          status: status,
        ),
      );

  @override
  Future<double> completionRatio(String userId, {String? planDate}) =>
      runDbGuarded(
        'PLAN_RATIO',
        () => _taskDao.completionRatio(
          userId,
          planDate ?? AppDateUtils.todayLocalDateString(),
        ),
      );

  @override
  Future<PagedList<StudyPlan>> planDays(
    String userId, {
    int page = 1,
    int pageSize = 30,
  }) =>
      runDbGuarded('PLAN_DAYS', () async {
        final int safePage = page < 1 ? 1 : page;
        final int offset = (safePage - 1) * pageSize;
        final List<StudyPlan> items =
            await _planDao.forUser(userId, limit: pageSize, offset: offset);
        final int total = await _planDao.countForUser(userId);
        return PagedList<StudyPlan>(
          items: items,
          total: total,
          limit: pageSize,
          offset: offset,
        );
      });

  @override
  Future<void> savePlanDays(List<StudyPlan> plans) =>
      runDbGuarded('PLAN_SAVE_DAYS', () => _planDao.insertAll(plans));

  @override
  Future<void> clearPlanDays(String userId) =>
      runDbGuarded('PLAN_CLEAR', () => _planDao.deleteForUser(userId));

  @override
  Future<PlanPhase> currentPhase(String userId, {int? daysRemaining}) async =>
      PlanPhase.fromDaysRemaining(daysRemaining);
}
