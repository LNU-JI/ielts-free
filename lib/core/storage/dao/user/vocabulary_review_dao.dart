/// DAO for `vocabulary_reviews`.
library;


import 'package:ielts_free/core/models/vocabulary_review.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// Reads and writes per-word memory state.
class VocabularyReviewDao extends BaseDao {
  VocabularyReviewDao(super.db);

  static const String _table = 'vocabulary_reviews';

  /// The review state of one word, or `null`.
  Future<VocabularyReview?> byVocabulary(
    String userId,
    int vocabularyId,
  ) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND vocabulary_id = ?',
      whereArgs: <Object?>[userId, vocabularyId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return VocabularyReview.fromMap(rows.first);
  }

  /// Inserts [review] or updates the existing row for `(user, vocabulary)`.
  ///
  /// Uses read-then-write (not `REPLACE`) so the row id and `created_at` are
  /// preserved across updates.
  Future<void> upsert(VocabularyReview review) async {
    final VocabularyReview? existing =
        await byVocabulary(review.userId ?? '', review.vocabularyId);
    if (existing?.id != null) {
      await db.update(
        _table,
        review.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[existing!.id],
      );
      return;
    }
    final Map<String, Object?> map = review.toMap()..remove('id');
    await db.insert(_table, map);
  }

  /// Words due for review, soonest first.
  Future<List<VocabularyReview>> due(
    String userId, {
    int limit = 20,
    int offset = 0,
    DateTime? now,
  }) async {
    final String stamp = AppDateUtils.toUtcIso(now ?? DateTime.now().toUtc());
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND (next_review_at IS NULL OR next_review_at <= ?)',
      whereArgs: <Object?>[userId, stamp],
      orderBy: 'next_review_at ASC, id ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(VocabularyReview.fromMap).toList(growable: false);
  }

  /// Number of words due for review.
  Future<int> countDue(String userId, {DateTime? now}) async {
    final String stamp = AppDateUtils.toUtcIso(now ?? DateTime.now().toUtc());
    return countRows(
      _table,
      where: 'user_id = ? AND (next_review_at IS NULL OR next_review_at <= ?)',
      whereArgs: <Object?>[userId, stamp],
    );
  }

  /// Favourited words.
  Future<List<VocabularyReview>> favorites(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND is_favorite = ?',
      whereArgs: <Object?>[userId, 1],
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(VocabularyReview.fromMap).toList(growable: false);
  }

  /// Sets the favourite flag for a word (creating a row when absent).
  Future<void> setFavorite(
    String userId,
    int vocabularyId,
    bool favorite,
  ) async {
    final VocabularyReview? existing =
        await byVocabulary(userId, vocabularyId);
    final String stamp = AppDateUtils.nowUtcIso();
    if (existing?.id != null) {
      await db.update(
        _table,
        <String, Object?>{
          'is_favorite': favorite ? 1 : 0,
          'updated_at': stamp,
        },
        where: 'id = ?',
        whereArgs: <Object?>[existing!.id],
      );
      return;
    }
    await db.insert(
      _table,
      <String, Object?>{
        'user_id': userId,
        'vocabulary_id': vocabularyId,
        'is_favorite': favorite ? 1 : 0,
        'created_at': stamp,
        'updated_at': stamp,
      },
    );
  }

  /// Number of mastered words.
  Future<int> countMastered(String userId) => countRows(
        _table,
        where: 'user_id = ? AND is_mastered = ?',
        whereArgs: <Object?>[userId, 1],
      );

  /// Number of tracked words.
  Future<int> countTracked(String userId) =>
      countRows(_table, where: 'user_id = ?', whereArgs: <Object?>[userId]);
}
