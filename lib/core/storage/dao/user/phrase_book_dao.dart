/// DAO for `phrase_book`.
///
/// Sentence patterns collected while writing. `phrase_book` has no unique
/// index, so deduplication by `(user_id, phrase)` is enforced here with a
/// read-then-write — safe because the user database is single-writer.
library;

import 'package:ielts_free/core/models/phrase_entry.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';

/// Reads and writes the phrase book.
class PhraseBookDao extends BaseDao {
  PhraseBookDao(super.db);

  static const String _table = 'phrase_book';

  /// Collects a phrase, returning the row id.
  ///
  /// Idempotent per `(user_id, phrase)`: re-collecting an existing phrase
  /// returns its id without inserting a duplicate.
  Future<int> add(PhraseEntry entry) async {
    final PhraseEntry? existing = await byPhrase(entry.userId, entry.phrase);
    final int? existingId = existing?.id;
    if (existingId != null) {
      return existingId;
    }
    final Map<String, Object?> map = entry.toMap()..remove('id');
    return db.insert(_table, map);
  }

  /// The entry for one `(user, phrase)` pair, or `null`.
  Future<PhraseEntry?> byPhrase(String userId, String phrase) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND phrase = ?',
      whereArgs: <Object?>[userId, phrase],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return PhraseEntry.fromMap(rows.first);
  }

  /// One page of collected phrases, newest first, optionally by [category].
  Future<List<PhraseEntry>> list(
    String userId, {
    int limit = 20,
    int offset = 0,
    String? category,
  }) async {
    final bool filtered = category != null && category.isNotEmpty;
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: filtered ? 'user_id = ? AND category = ?' : 'user_id = ?',
      whereArgs: filtered
          ? <Object?>[userId, category]
          : <Object?>[userId],
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(PhraseEntry.fromMap).toList(growable: false);
  }

  /// Number of collected phrases, optionally filtered by [category].
  Future<int> count(String userId, {String? category}) async {
    final bool filtered = category != null && category.isNotEmpty;
    return countRows(
      _table,
      where: filtered ? 'user_id = ? AND category = ?' : 'user_id = ?',
      whereArgs: filtered
          ? <Object?>[userId, category]
          : <Object?>[userId],
    );
  }

  /// Deletes one collected phrase.
  Future<void> delete(int id) async {
    await db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id]);
  }
}
