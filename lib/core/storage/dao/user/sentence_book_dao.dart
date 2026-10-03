/// DAO for `sentence_book`.
///
/// Hard-to-hear sentences kept for repeat practice. Bookmarks are deduplicated
/// by `(user_id, source_type, source_id)` — the unique index
/// `idx_sb_source` makes the insert idempotent, and a repeat bookmark refreshes
/// the display fields without losing the review progress.
library;

import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/models/sentence_entry.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';

/// Reads and writes the sentence book.
class SentenceBookDao extends BaseDao {
  SentenceBookDao(super.db);

  static const String _table = 'sentence_book';

  /// Bookmarks a sentence, returning the row id.
  ///
  /// `INSERT OR IGNORE` handles the duplicate; the existing row is then looked
  /// up and its mutable display fields refreshed, so `review_count` /
  /// `mastered` survive re-bookmarking. The row id is read back rather than
  /// taken from the insert, so the result is correct whether the insert landed
  /// or was ignored.
  Future<int> add(SentenceEntry entry) async {
    final Map<String, Object?> map = entry.toMap()..remove('id');
    final int insertedId = await db.insert(
      _table,
      map,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final SentenceEntry? existing =
        await bySource(entry.userId, entry.sourceType, entry.sourceId);
    final int? existingId = existing?.id;
    if (existingId == null) {
      return insertedId;
    }
    await db.update(
      _table,
      <String, Object?>{
        'text': entry.text,
        'translation': entry.translation,
        'note': entry.note,
        'section_id': entry.sectionId,
      },
      where: 'id = ?',
      whereArgs: <Object?>[existingId],
    );
    return existingId;
  }

  /// The bookmark for one source sentence, or `null`.
  Future<SentenceEntry?> bySource(
    String userId,
    String sourceType,
    int sourceId,
  ) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND source_type = ? AND source_id = ?',
      whereArgs: <Object?>[userId, sourceType, sourceId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return SentenceEntry.fromMap(rows.first);
  }

  /// One page of bookmarks, newest first, optionally filtered.
  Future<List<SentenceEntry>> list(
    String userId, {
    int limit = 20,
    int offset = 0,
    String? sourceType,
    bool? mastered,
  }) async {
    final List<String> clauses = <String>['user_id = ?'];
    final List<Object?> args = <Object?>[userId];
    if (sourceType != null && sourceType.isNotEmpty) {
      clauses.add('source_type = ?');
      args.add(sourceType);
    }
    if (mastered != null) {
      clauses.add('mastered = ?');
      args.add(mastered ? 1 : 0);
    }
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(SentenceEntry.fromMap).toList(growable: false);
  }

  /// Number of bookmarks matching the filter.
  Future<int> count(
    String userId, {
    String? sourceType,
    bool? mastered,
  }) async {
    final List<String> clauses = <String>['user_id = ?'];
    final List<Object?> args = <Object?>[userId];
    if (sourceType != null && sourceType.isNotEmpty) {
      clauses.add('source_type = ?');
      args.add(sourceType);
    }
    if (mastered != null) {
      clauses.add('mastered = ?');
      args.add(mastered ? 1 : 0);
    }
    return countRows(_table, where: clauses.join(' AND '), whereArgs: args);
  }

  /// All bookmarks from one source module, newest first.
  Future<List<SentenceEntry>> forSourceType(
    String userId,
    String sourceType,
  ) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND source_type = ?',
      whereArgs: <Object?>[userId, sourceType],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(SentenceEntry.fromMap).toList(growable: false);
  }

  /// Sets the mastered flag of one bookmark.
  Future<void> markMastered(int id, bool mastered) async {
    await db.update(
      _table,
      <String, Object?>{'mastered': mastered ? 1 : 0},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Increments the review counter of one bookmark.
  Future<void> incrementReview(int id) async {
    await db.rawUpdate(
      'UPDATE $_table SET review_count = review_count + 1 WHERE id = ?',
      <Object?>[id],
    );
  }

  /// Deletes one bookmark.
  Future<void> delete(int id) async {
    await db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id]);
  }
}
