/// Study-goal repository.
library;

import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/study_goal.dart';
import 'package:ielts_free/core/models/user.dart';
import 'package:ielts_free/core/storage/dao/user/study_goal_dao.dart';
import 'package:ielts_free/core/storage/dao/user/user_dao.dart';

/// Read/write access to study goals.
abstract interface class StudyGoalRepository {
  /// The active goal for [userId], or `null`.
  Future<StudyGoal?> active(String userId);

  /// Returns the active goal, creating the default guest goal when absent.
  Future<StudyGoal> ensureDefault({String? userId});

  /// Makes [goal] the active goal (deactivating the previous one).
  Future<StudyGoal> saveActive(StudyGoal goal);

  /// Updates an existing goal in place.
  Future<void> update(StudyGoal goal);
}

/// SQLite-backed [StudyGoalRepository].
class SqliteStudyGoalRepository implements StudyGoalRepository {
  SqliteStudyGoalRepository(this._goalDao, this._userDao);

  final StudyGoalDao _goalDao;
  final UserDao _userDao;

  @override
  Future<StudyGoal?> active(String userId) =>
      runDbGuarded('GOAL_ACTIVE', () => _goalDao.activeForUser(userId));

  @override
  Future<StudyGoal> ensureDefault({String? userId}) =>
      runDbGuarded('GOAL_ENSURE', () async {
        final String id = userId ?? User.localUser().id;
        await _userDao.ensure(id);
        final StudyGoal? existing = await _goalDao.activeForUser(id);
        if (existing != null) {
          return existing;
        }
        final StudyGoal goal = StudyGoal.localDefault();
        final int newId = await _goalDao.saveActive(goal);
        return StudyGoal(
          id: newId,
          userId: goal.userId,
          targetBand: goal.targetBand,
          examDate: goal.examDate,
          dailyStudyMinutes: goal.dailyStudyMinutes,
          planType: goal.planType,
          planStartDate: goal.planStartDate,
          planEndDate: goal.planEndDate,
          isActive: true,
          createdAt: goal.createdAt,
          updatedAt: goal.updatedAt,
        );
      });

  @override
  Future<StudyGoal> saveActive(StudyGoal goal) =>
      runDbGuarded('GOAL_SAVE', () async {
        await _userDao.ensure(goal.userId);
        final int newId = await _goalDao.saveActive(goal);
        return StudyGoal(
          id: newId,
          userId: goal.userId,
          targetBand: goal.targetBand,
          examDate: goal.examDate,
          dailyStudyMinutes: goal.dailyStudyMinutes,
          planType: goal.planType,
          planStartDate: goal.planStartDate,
          planEndDate: goal.planEndDate,
          isActive: true,
          createdAt: goal.createdAt,
          updatedAt: goal.updatedAt,
        );
      });

  @override
  Future<void> update(StudyGoal goal) =>
      runDbGuarded('GOAL_UPDATE', () => _goalDao.update(goal));
}
