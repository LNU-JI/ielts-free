/// Read-only DAO for reading content
/// (`reading_passages` / `reading_questions` / `reading_options`).
///
/// **SELECT-only** (docs/ARCHITECTURE-v0.1.md §4.1). Lists are paginated.
library;


import 'package:ielts_free/core/models/reading_option.dart';
import 'package:ielts_free/core/models/reading_passage.dart';
import 'package:ielts_free/core/models/reading_question.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';

/// Queries reading content.
class ReadingDao extends BaseDao {
  ReadingDao(super.db);

  /// One page of passages, optionally filtered by [difficulty] and [topic].
  Future<List<ReadingPassage>> page({
    int limit = 20,
    int offset = 0,
    int? difficulty,
    String? topic,
  }) async {
    final List<String> clauses = <String>[];
    final List<Object?> args = <Object?>[];
    if (difficulty != null) {
      clauses.add('difficulty = ?');
      args.add(difficulty);
    }
    if (topic != null && topic.isNotEmpty) {
      clauses.add('topic = ?');
      args.add(topic);
    }
    final List<Map<String, Object?>> rows = await db.query(
      'reading_passages',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: clauses.isEmpty ? null : args,
      orderBy: 'id ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(ReadingPassage.fromMap).toList(growable: false);
  }

  /// Total number of passages (respecting an optional topic filter).
  Future<int> countPassages({String? topic}) async {
    if (topic != null && topic.isNotEmpty) {
      return countRows('reading_passages', where: 'topic = ?', whereArgs: <Object?>[topic]);
    }
    return countRows('reading_passages');
  }

  /// Total number of questions.
  Future<int> countQuestions() => countRows('reading_questions');

  /// Returns the passage with [id], or `null`.
  Future<ReadingPassage?> passageById(int id) async {
    final List<Map<String, Object?>> rows = await db.query(
      'reading_passages',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return ReadingPassage.fromMap(rows.first);
  }

  /// Questions of a passage, ordered by `order_index` (options not attached).
  Future<List<ReadingQuestion>> questionsForPassage(int passageId) async {
    final List<Map<String, Object?>> rows = await db.query(
      'reading_questions',
      where: 'passage_id = ?',
      whereArgs: <Object?>[passageId],
      orderBy: 'order_index ASC',
    );
    return rows.map(ReadingQuestion.fromMap).toList(growable: false);
  }

  /// Questions of a passage with their options attached (single extra query).
  Future<List<ReadingQuestion>> questionsWithOptions(int passageId) async {
    final List<ReadingQuestion> questions =
        await questionsForPassage(passageId);
    if (questions.isEmpty) {
      return questions;
    }

    final List<int> questionIds =
        questions.map((ReadingQuestion q) => q.id).toList(growable: false);
    final String placeholders =
        List<String>.filled(questionIds.length, '?').join(',');
    final List<Map<String, Object?>> optionRows = await db.query(
      'reading_options',
      where: 'question_id IN ($placeholders)',
      whereArgs: questionIds.cast<Object?>(),
      orderBy: 'question_id ASC, order_index ASC',
    );

    final Map<int, List<ReadingOption>> grouped =
        <int, List<ReadingOption>>{};
    for (final Map<String, Object?> row in optionRows) {
      final ReadingOption option = ReadingOption.fromMap(row);
      grouped.putIfAbsent(option.questionId, () => <ReadingOption>[]).add(option);
    }

    return questions
        .map((ReadingQuestion q) =>
            q.withOptions(grouped[q.id] ?? const <ReadingOption>[]))
        .toList(growable: false);
  }

  /// Returns the question with [id] (options not attached), or `null`.
  Future<ReadingQuestion?> questionById(int id) async {
    final List<Map<String, Object?>> rows = await db.query(
      'reading_questions',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return ReadingQuestion.fromMap(rows.first);
  }

  /// Options of one question.
  Future<List<ReadingOption>> optionsForQuestion(int questionId) async {
    final List<Map<String, Object?>> rows = await db.query(
      'reading_options',
      where: 'question_id = ?',
      whereArgs: <Object?>[questionId],
      orderBy: 'order_index ASC',
    );
    return rows.map(ReadingOption.fromMap).toList(growable: false);
  }

  /// Distinct passage topics (for filter chips).
  Future<List<String>> distinctTopics() async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT DISTINCT topic FROM reading_passages '
      'WHERE topic IS NOT NULL ORDER BY topic ASC',
    );
    return rows
        .map((Map<String, Object?> r) => r['topic'] as String? ?? '')
        .where((String t) => t.isNotEmpty)
        .toList(growable: false);
  }

  /// Number of questions per question type.
  Future<Map<String, int>> countByType() async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT question_type, COUNT(*) AS c FROM reading_questions '
      'GROUP BY question_type',
    );
    return <String, int>{
      for (final Map<String, Object?> row in rows)
        (row['question_type'] as String? ?? ''): (row['c'] as int? ?? 0),
    };
  }
}
