/// Schema-consistency test — the user DDL, the content DDL and the pipeline SQL
/// must agree, and the tables / indexes / columns the DAOs rely on must exist.
///
/// This is the cheapest guard against the classic hand-written-SQL defect: a
/// query referencing a column that the schema never created (no compiler catches
/// it — see docs/TEST-REPORT-v0.1.md).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/database/schema_content.dart';

import '../../helpers/test_database.dart';

void main() {
  setUpAll(initTestDatabaseFactory);

  group('user database schema', () {
    late Database db;

    setUp(() async {
      db = await openInMemoryUserDb(version: 1);
    });

    tearDown(() async {
      await db.close();
    });

    const List<String> expectedTables = <String>[
      'users',
      'user_profile',
      'study_goal',
      'study_plan',
      'daily_tasks',
      'vocabulary_reviews',
      'skill_scores',
      'user_answers',
      'mistakes',
      'learning_sessions',
      'learning_statistics',
      'favorites',
      'notes',
      'app_settings',
      'content_metadata',
    ];

    const List<String> expectedIndexes = <String>[
      'idx_sg_user',
      'idx_sg_active',
      'idx_sp_user_date',
      'idx_dt_user_date',
      'idx_dt_status',
      'idx_vr_user_vocab',
      'idx_vr_due',
      'idx_ss_user_skill',
      'idx_ua_user_time',
      'idx_ua_skill',
      'idx_mk_user',
      'idx_mk_type',
      'idx_mk_error',
      'idx_mk_unique',
      'idx_ls_user_start',
      'idx_st_user_date',
      'idx_fav_unique',
      'idx_note_user_ref',
      'idx_settings_user_key',
    ];

    Future<List<String>> names(String type) async {
      final List<Map<String, Object?>> rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = ?",
        <Object?>[type],
      );
      return rows
          .map((Map<String, Object?> r) => r['name']! as String)
          .toList(growable: false);
    }

    Future<List<String>> columnsOf(String table) async {
      final List<Map<String, Object?>> rows =
          await db.rawQuery('PRAGMA table_info($table)');
      return rows
          .map((Map<String, Object?> r) => r['name']! as String)
          .toList(growable: false);
    }

    test('every expected table exists', () async {
      final List<String> tables = await names('table');
      for (final String table in expectedTables) {
        expect(tables, contains(table), reason: 'missing table $table');
      }
    });

    test('every expected index exists', () async {
      final List<String> indexes = await names('index');
      for (final String index in expectedIndexes) {
        expect(indexes, contains(index), reason: 'missing index $index');
      }
    });

    test('critical columns exist (guards DAO column-name drift)', () async {
      expect(await columnsOf('user_answers'), containsAll(<String>[
        'user_id', 'ref_type', 'ref_id', 'skill', 'user_answer',
        'is_correct', 'difficulty', 'time_spent_ms', 'session_id', 'answered_at',
      ]));
      expect(await columnsOf('mistakes'), containsAll(<String>[
        'user_id', 'ref_type', 'ref_id', 'question_type', 'skill',
        'user_answer', 'correct_answer', 'error_type', 'difficulty',
        'wrong_count', 'last_wrong_at', 'mastery',
      ]));
      expect(await columnsOf('skill_scores'), containsAll(<String>[
        'user_id', 'skill', 'score', 'current_difficulty', 'sample_count',
        'last_practiced_at', 'updated_at',
      ]));
      expect(await columnsOf('vocabulary_reviews'), containsAll(<String>[
        'user_id', 'vocabulary_id', 'memory_level', 'correct_count',
        'wrong_count', 'streak', 'last_reviewed_at', 'next_review_at',
        'is_mastered', 'is_favorite',
      ]));
      expect(await columnsOf('daily_tasks'), containsAll(<String>[
        'user_id', 'plan_date', 'task_type', 'skill', 'title',
        'target_minutes', 'item_count', 'completed_count', 'status',
        'sort_order', 'payload',
      ]));
      expect(await columnsOf('learning_statistics'), containsAll(<String>[
        'user_id', 'stat_date', 'study_minutes', 'questions_answered',
        'correct_count', 'words_reviewed', 'words_mastered', 'current_streak',
        'last_study_date', 'total_study_minutes', 'total_days',
      ]));
    });

    test('memory_level CHECK rejects out-of-range values', () async {
      await db.insert('users', <String, Object?>{
        'id': 'u',
        'created_at': '2026-01-01T00:00:00.000Z',
      });
      await expectLater(
        db.insert('vocabulary_reviews', <String, Object?>{
          'user_id': 'u',
          'vocabulary_id': 1,
          'memory_level': 9,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('content schema parity', () {
    test('schema_content.dart matches content_pipeline/schema.sql', () {
      final File file = File('content_pipeline/schema.sql');
      expect(file.existsSync(), isTrue,
          reason: 'run from the package root (flutter test does)');

      // Comments carry no schema meaning, so they do not participate in the
      // DDL comparison. Both sides must have their `--` line comments stripped
      // (the Dart string is not pre-processed like the .sql file), otherwise a
      // comment block that exists identically in both copies is reported as a
      // spurious difference. Mirrors `tool/verify/schema_diff.py`'s `norm_list`.
      List<String> normalise(String sql) => sql
          .split('\n')
          .where((String l) => !l.trimLeft().startsWith('--'))
          .join('\n')
          .split(';')
          .map((String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((String s) => s.isNotEmpty)
          .toList(growable: false);

      expect(normalise(contentSchemaStatements().join(';')), isNotEmpty);
      expect(
        normalise(file.readAsStringSync()),
        normalise(kContentSchemaSql),
        reason: 'the two content schemas must be statement-for-statement equal',
      );
    });
  });
}
