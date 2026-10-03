/// Read-only DAO for writing content
/// (`writing_tasks` / `writing_samples` / `writing_phrases`).
///
/// **SELECT-only** (docs/ARCHITECTURE-v0.1.md §4.1). Lists are paginated and
/// the caller composes a full task from [taskById] and [samplesForTask].
library;

import 'package:ielts_free/core/models/writing_phrase.dart';
import 'package:ielts_free/core/models/writing_sample.dart';
import 'package:ielts_free/core/models/writing_task.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';

/// Queries writing content.
class WritingDao extends BaseDao {
  WritingDao(super.db);

  /// One page of tasks, optionally filtered by [task] number (1 or 2).
  Future<List<WritingTask>> page({
    int limit = 20,
    int offset = 0,
    int? task,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      'writing_tasks',
      where: task == null ? null : 'task = ?',
      whereArgs: task == null ? null : <Object?>[task],
      orderBy: 'id ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(WritingTask.fromMap).toList(growable: false);
  }

  /// Total number of tasks (respecting an optional [task] filter).
  Future<int> countTasks({int? task}) async {
    if (task != null) {
      return countRows(
        'writing_tasks',
        where: 'task = ?',
        whereArgs: <Object?>[task],
      );
    }
    return countRows('writing_tasks');
  }

  /// Returns the task with [id], or `null`.
  Future<WritingTask?> taskById(int id) async {
    final List<Map<String, Object?>> rows = await db.query(
      'writing_tasks',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return WritingTask.fromMap(rows.first);
  }

  /// Model essays of a task, ordered by `id`.
  Future<List<WritingSample>> samplesForTask(int taskId) async {
    final List<Map<String, Object?>> rows = await db.query(
      'writing_samples',
      where: 'task_id = ?',
      whereArgs: <Object?>[taskId],
      orderBy: 'id ASC',
    );
    return rows.map(WritingSample.fromMap).toList(growable: false);
  }

  /// One page of phrases, optionally filtered by [category] and [task].
  Future<List<WritingPhrase>> phrases({
    int limit = 20,
    int offset = 0,
    String? category,
    int? task,
  }) async {
    final List<String> clauses = <String>[];
    final List<Object?> args = <Object?>[];
    if (category != null && category.isNotEmpty) {
      clauses.add('category = ?');
      args.add(category);
    }
    if (task != null) {
      clauses.add('task = ?');
      args.add(task);
    }
    final List<Map<String, Object?>> rows = await db.query(
      'writing_phrases',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: clauses.isEmpty ? null : args,
      orderBy: 'category ASC, id ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(WritingPhrase.fromMap).toList(growable: false);
  }

  /// Total number of phrases (respecting optional [category] / [task] filters).
  Future<int> countPhrases({String? category, int? task}) async {
    final List<String> clauses = <String>[];
    final List<Object?> args = <Object?>[];
    if (category != null && category.isNotEmpty) {
      clauses.add('category = ?');
      args.add(category);
    }
    if (task != null) {
      clauses.add('task = ?');
      args.add(task);
    }
    return countRows(
      'writing_phrases',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: clauses.isEmpty ? null : args,
    );
  }

  /// Distinct phrase categories (for filter chips).
  Future<List<String>> distinctCategories() async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT DISTINCT category FROM writing_phrases '
      'WHERE category IS NOT NULL ORDER BY category ASC',
    );
    return rows
        .map((Map<String, Object?> r) => r['category'] as String? ?? '')
        .where((String c) => c.isNotEmpty)
        .toList(growable: false);
  }

  /// A random task, optionally restricted to [task] number; `null` when none.
  Future<WritingTask?> randomTask({int? task}) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      task == null
          ? 'SELECT * FROM writing_tasks ORDER BY RANDOM() LIMIT 1'
          : 'SELECT * FROM writing_tasks WHERE task = ? '
              'ORDER BY RANDOM() LIMIT 1',
      task == null ? null : <Object?>[task],
    );
    if (rows.isEmpty) {
      return null;
    }
    return WritingTask.fromMap(rows.first);
  }
}
