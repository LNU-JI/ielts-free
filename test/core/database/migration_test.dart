/// Migration test — FR-083 / NFR-30 / BRIEF §71–75.
///
/// The **key acceptance** is "upgrading the database must never lose user data".
/// This test creates a real v1 database, writes representative rows into every
/// user table, upgrades it to v2 through the real [runMigrations] script, and
/// asserts that nothing was lost, no table was dropped and the new columns
/// arrived with their defaults.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/database/migrations.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(initTestDatabaseFactory);

  late Directory dir;
  late String path;

  setUp(() {
    dir = createTestTempDir();
    path = tempFilePath(dir, 'ielts_user_v1.db');
  });

  tearDown(() => deleteTestTempDir(dir));

  Future<void> seedV1(Database db) async {
    await db.insert('users', <String, Object?>{
      'id': 'local_user',
      'created_at': '2026-01-01T00:00:00.000Z',
    });
    await db.insert('user_profile', <String, Object?>{
      'user_id': 'local_user',
      'display_name': 'Local User',
      'weakest_skill': 'READING',
      'onboarding_completed': 1,
      'created_at': '2026-01-01T00:00:00.000Z',
    });
    await db.insert('study_goal', <String, Object?>{
      'user_id': 'local_user',
      'target_band': 7.0,
      'exam_date': '2026-06-01',
      'daily_study_minutes': 60,
      'plan_type': 'DAY90',
      'is_active': 1,
    });
    await db.insert('mistakes', <String, Object?>{
      'user_id': 'local_user',
      'ref_type': 'READING',
      'ref_id': 101,
      'question_type': 'TFNG',
      'skill': 'READING_TFNG',
      'user_answer': 'FALSE',
      'correct_answer': 'NOT GIVEN',
      'error_type': 'READING_PARAPHRASE',
      'difficulty': 3,
      'wrong_count': 2,
      'last_wrong_at': '2026-01-02T00:00:00.000Z',
      'mastery': 0.0,
    });
    await db.insert('vocabulary_reviews', <String, Object?>{
      'user_id': 'local_user',
      'vocabulary_id': 5,
      'memory_level': 2,
      'correct_count': 3,
      'wrong_count': 1,
      'streak': 2,
      'is_mastered': 0,
    });
    await db.insert('skill_scores', <String, Object?>{
      'user_id': 'local_user',
      'skill': 'READING_TFNG',
      'score': 55.0,
      'current_difficulty': 3,
      'sample_count': 12,
    });
    await db.insert('learning_statistics', <String, Object?>{
      'user_id': 'local_user',
      'stat_date': '2026-01-02',
      'study_minutes': 25,
      'questions_answered': 10,
      'correct_count': 6,
      'current_streak': 3,
      'last_study_date': '2026-01-02',
      'total_days': 3,
    });
    await db.insert('user_answers', <String, Object?>{
      'user_id': 'local_user',
      'ref_type': 'READING',
      'ref_id': 101,
      'skill': 'READING_TFNG',
      'user_answer': 'FALSE',
      'is_correct': 0,
      'difficulty': 3,
      'answered_at': '2026-01-02T00:00:00.000Z',
    });
  }

  Future<Map<String, Object?>> snapshot(Database db) async {
    Future<int> count(String table) async =>
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $table'),
        ) ??
        0;
    final List<Map<String, Object?>> goal = await db.query('study_goal');
    final List<Map<String, Object?>> mistake = await db.query('mistakes');
    final List<Map<String, Object?>> review = await db.query('vocabulary_reviews');
    final List<Map<String, Object?>> score = await db.query('skill_scores');
    final List<Map<String, Object?>> stats = await db.query('learning_statistics');
    return <String, Object?>{
      'users': await count('users'),
      'user_profile': await count('user_profile'),
      'study_goal': await count('study_goal'),
      'mistakes': await count('mistakes'),
      'vocabulary_reviews': await count('vocabulary_reviews'),
      'skill_scores': await count('skill_scores'),
      'learning_statistics': await count('learning_statistics'),
      'user_answers': await count('user_answers'),
      'goal_target_band': goal.first['target_band'],
      'mistake_wrong_count': mistake.first['wrong_count'],
      'review_memory_level': review.first['memory_level'],
      'skill_score': score.first['score'],
      'streak': stats.first['current_streak'],
    };
  }

  test('runMigrations(1 → 2) preserves every user row and adds columns',
      () async {
    final Database v1 = await openUserDbAt(path, version: 1);
    await seedV1(v1);
    final Map<String, Object?> before = await snapshot(v1);
    final List<String> tablesBefore = (await v1.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    ))
        .map((Map<String, Object?> r) => r['name']! as String)
        .toList(growable: false);
    expect(
      Sqflite.firstIntValue(await v1.rawQuery('PRAGMA user_version')),
      1,
    );
    await v1.close();

    // Re-opening with version 2 fires onUpgrade → runMigrations(1 → 2).
    final Database v2 = await openUserDbAt(path, version: 2);
    final Map<String, Object?> after = await snapshot(v2);
    final List<String> tablesAfter = (await v2.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    ))
        .map((Map<String, Object?> r) => r['name']! as String)
        .toList(growable: false);
    final List<Map<String, Object?>> profileCols =
        await v2.rawQuery('PRAGMA table_info(user_profile)');
    final List<String> profileColumnNames = profileCols
        .map((Map<String, Object?> r) => r['name']! as String)
        .toList(growable: false);

    // 1. Every row survived.
    for (final String key in before.keys) {
      expect(after[key], before[key], reason: 'column "$key" changed');
    }
    // 2. No table was dropped.
    for (final String table in tablesBefore) {
      expect(tablesAfter, contains(table));
    }
    // 3. Version bumped and new columns present with their defaults.
    expect(Sqflite.firstIntValue(await v2.rawQuery('PRAGMA user_version')), 2);
    expect(profileColumnNames, contains('font_scale'));
    expect(profileColumnNames, contains('theme_mode'));
    final List<Map<String, Object?>> profile = await v2.query('user_profile');
    expect(profile.first['font_scale'], 1.0);
    expect(profile.first['theme_mode'], 'system');
    // 4. The additive index from step 2 exists.
    final List<Map<String, Object?>> indexes = await v2.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_ua_user_correct'",
    );
    expect(indexes, hasLength(1));
    // 5. Foreign keys still intact.
    expect(await v2.rawQuery('PRAGMA foreign_key_check'), isEmpty);

    await v2.close();
  });

  test('runMigrations is a no-op when from == to', () async {
    final Database db = await openUserDbAt(path, version: 1);
    await seedV1(db);
    await runMigrations(db, from: 1, to: 1);
    expect(
      Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users')),
      1,
    );
    await db.close();
  });

  test('the v1 schema and the v2 step are append-only (no DROP / DELETE)',
      () async {
    // Guard rail: the migration SQL must never drop or delete.
    for (final List<String> steps in migrationSteps.values) {
      for (final String sql in steps) {
        final String upper = sql.toUpperCase();
        expect(upper.contains('DROP TABLE'), isFalse, reason: sql);
        expect(upper.contains('DROP COLUMN'), isFalse, reason: sql);
        expect(upper.contains('DELETE FROM'), isFalse, reason: sql);
        expect(upper.contains('TRUNCATE'), isFalse, reason: sql);
      }
    }
  });
}
