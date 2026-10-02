/// Repository providers.
///
/// Wires the DAOs to the repository interfaces and exposes them to the
/// application layer. Only these repository providers are meant to be read by
/// controllers — never the DAOs directly (docs/ARCHITECTURE-v0.1.md §1.1).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/providers/database_providers.dart';
import 'package:ielts_free/core/storage/dao/content/content_meta_dao.dart';
import 'package:ielts_free/core/storage/dao/content/reading_dao.dart';
import 'package:ielts_free/core/storage/dao/content/vocabulary_dao.dart';
import 'package:ielts_free/core/storage/dao/user/daily_task_dao.dart';
import 'package:ielts_free/core/storage/dao/user/favorite_dao.dart';
import 'package:ielts_free/core/storage/dao/user/mistake_dao.dart';
import 'package:ielts_free/core/storage/dao/user/note_dao.dart';
import 'package:ielts_free/core/storage/dao/user/session_dao.dart';
import 'package:ielts_free/core/storage/dao/user/settings_dao.dart';
import 'package:ielts_free/core/storage/dao/user/skill_score_dao.dart';
import 'package:ielts_free/core/storage/dao/user/statistics_dao.dart';
import 'package:ielts_free/core/storage/dao/user/study_goal_dao.dart';
import 'package:ielts_free/core/storage/dao/user/study_plan_dao.dart';
import 'package:ielts_free/core/storage/dao/user/user_answer_dao.dart';
import 'package:ielts_free/core/storage/dao/user/user_dao.dart';
import 'package:ielts_free/core/storage/dao/user/user_profile_dao.dart';
import 'package:ielts_free/core/storage/dao/user/vocabulary_review_dao.dart';
import 'package:ielts_free/core/storage/repositories/backup_repository.dart';
import 'package:ielts_free/core/storage/repositories/mistake_repository.dart';
import 'package:ielts_free/core/storage/repositories/plan_repository.dart';
import 'package:ielts_free/core/storage/repositories/progress_repository.dart';
import 'package:ielts_free/core/storage/repositories/reading_repository.dart';
import 'package:ielts_free/core/storage/repositories/settings_repository.dart';
import 'package:ielts_free/core/storage/repositories/study_goal_repository.dart';
import 'package:ielts_free/core/storage/repositories/user_profile_repository.dart';
import 'package:ielts_free/core/storage/repositories/vocabulary_repository.dart';

// --- Content repositories ---------------------------------------------------

/// Vocabulary content repository.
final FutureProvider<VocabularyRepository> vocabularyRepositoryProvider =
    FutureProvider<VocabularyRepository>((Ref ref) async {
  final Database db = await ref.watch(contentDbProvider.future);
  return SqliteVocabularyRepository(VocabularyDao(db));
});

/// Reading content repository.
final FutureProvider<ReadingRepository> readingRepositoryProvider =
    FutureProvider<ReadingRepository>((Ref ref) async {
  final Database db = await ref.watch(contentDbProvider.future);
  return SqliteReadingRepository(ReadingDao(db));
});

/// Content-metadata DAO (used by the bootstrap sequence in T03).
final FutureProvider<ContentMetaDao> contentMetaDaoProvider =
    FutureProvider<ContentMetaDao>((Ref ref) async {
  final Database db = await ref.watch(contentDbProvider.future);
  return ContentMetaDao(db);
});

// --- User repositories ------------------------------------------------------

/// User profile repository.
final FutureProvider<UserProfileRepository> userProfileRepositoryProvider =
    FutureProvider<UserProfileRepository>((Ref ref) async {
  final Database db = await ref.watch(userDbProvider.future);
  return SqliteUserProfileRepository(UserProfileDao(db), UserDao(db));
});

/// Study goal repository.
final FutureProvider<StudyGoalRepository> studyGoalRepositoryProvider =
    FutureProvider<StudyGoalRepository>((Ref ref) async {
  final Database db = await ref.watch(userDbProvider.future);
  return SqliteStudyGoalRepository(StudyGoalDao(db), UserDao(db));
});

/// Plan repository (daily tasks + study-plan days).
final FutureProvider<PlanRepository> planRepositoryProvider =
    FutureProvider<PlanRepository>((Ref ref) async {
  final Database db = await ref.watch(userDbProvider.future);
  return SqlitePlanRepository(DailyTaskDao(db), StudyPlanDao(db));
});

/// Mistake repository.
final FutureProvider<MistakeRepository> mistakeRepositoryProvider =
    FutureProvider<MistakeRepository>((Ref ref) async {
  final Database db = await ref.watch(userDbProvider.future);
  return SqliteMistakeRepository(MistakeDao(db));
});

/// Progress repository (memory, answers, scores, statistics, sessions).
final FutureProvider<ProgressRepository> progressRepositoryProvider =
    FutureProvider<ProgressRepository>((Ref ref) async {
  final Database db = await ref.watch(userDbProvider.future);
  return SqliteProgressRepository(
    reviewDao: VocabularyReviewDao(db),
    answerDao: UserAnswerDao(db),
    skillScoreDao: SkillScoreDao(db),
    statisticsDao: StatisticsDao(db),
    sessionDao: SessionDao(db),
  );
});

/// Settings repository.
final FutureProvider<SettingsRepository> settingsRepositoryProvider =
    FutureProvider<SettingsRepository>((Ref ref) async {
  final Database db = await ref.watch(userDbProvider.future);
  return SqliteSettingsRepository(SettingsDao(db));
});

/// Backup repository.
final FutureProvider<BackupRepository> backupRepositoryProvider =
    FutureProvider<BackupRepository>((Ref ref) async {
  final Database db = await ref.watch(userDbProvider.future);
  final String path = await ref.watch(appDatabaseProvider).databasePath();
  return SqliteBackupRepository(db, databasePath: path);
});

// --- Additional user DAOs (exposed for controllers that need them) ----------

/// Favourite DAO.
final FutureProvider<FavoriteDao> favoriteDaoProvider =
    FutureProvider<FavoriteDao>((Ref ref) async {
  final Database db = await ref.watch(userDbProvider.future);
  return FavoriteDao(db);
});

/// Note DAO.
final FutureProvider<NoteDao> noteDaoProvider =
    FutureProvider<NoteDao>((Ref ref) async {
  final Database db = await ref.watch(userDbProvider.future);
  return NoteDao(db);
});
