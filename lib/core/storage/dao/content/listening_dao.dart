/// Read-only DAO for listening content
/// (`listening_sections` / `listening_cues` / `listening_questions`).
///
/// **SELECT-only** (docs/ARCHITECTURE-v0.1.md §4.1). Lists are paginated and
/// the caller composes a full training set from [sectionById],
/// [cuesForSection] and [questionsForSection].
library;

import 'package:ielts_free/core/models/listening_cue.dart';
import 'package:ielts_free/core/models/listening_question.dart';
import 'package:ielts_free/core/models/listening_section.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';

/// Queries listening content.
class ListeningDao extends BaseDao {
  ListeningDao(super.db);

  /// One page of sections, optionally filtered by IELTS [part] (1–4).
  Future<List<ListeningSection>> page({
    int limit = 20,
    int offset = 0,
    int? part,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      'listening_sections',
      where: part == null ? null : 'part = ?',
      whereArgs: part == null ? null : <Object?>[part],
      orderBy: 'id ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(ListeningSection.fromMap).toList(growable: false);
  }

  /// Total number of sections (respecting an optional [part] filter).
  Future<int> countSections({int? part}) async {
    if (part != null) {
      return countRows(
        'listening_sections',
        where: 'part = ?',
        whereArgs: <Object?>[part],
      );
    }
    return countRows('listening_sections');
  }

  /// Returns the section with [id], or `null`.
  Future<ListeningSection?> sectionById(int id) async {
    final List<Map<String, Object?>> rows = await db.query(
      'listening_sections',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return ListeningSection.fromMap(rows.first);
  }

  /// Cues of a section, ordered by `order_index`.
  Future<List<ListeningCue>> cuesForSection(int sectionId) async {
    final List<Map<String, Object?>> rows = await db.query(
      'listening_cues',
      where: 'section_id = ?',
      whereArgs: <Object?>[sectionId],
      orderBy: 'order_index ASC',
    );
    return rows.map(ListeningCue.fromMap).toList(growable: false);
  }

  /// Questions of a section, ordered by `order_index`.
  Future<List<ListeningQuestion>> questionsForSection(int sectionId) async {
    final List<Map<String, Object?>> rows = await db.query(
      'listening_questions',
      where: 'section_id = ?',
      whereArgs: <Object?>[sectionId],
      orderBy: 'order_index ASC',
    );
    return rows.map(ListeningQuestion.fromMap).toList(growable: false);
  }

  /// A random section, optionally restricted to [part]; `null` when none exist.
  Future<ListeningSection?> randomSection({int? part}) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      part == null
          ? 'SELECT * FROM listening_sections ORDER BY RANDOM() LIMIT 1'
          : 'SELECT * FROM listening_sections WHERE part = ? '
              'ORDER BY RANDOM() LIMIT 1',
      part == null ? null : <Object?>[part],
    );
    if (rows.isEmpty) {
      return null;
    }
    return ListeningSection.fromMap(rows.first);
  }
}
