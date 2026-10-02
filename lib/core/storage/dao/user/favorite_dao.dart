/// DAO for `favorites`.
library;

import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/models/enums/ref_type.dart';
import 'package:ielts_free/core/models/favorite.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// Reads and writes favourites.
class FavoriteDao extends BaseDao {
  FavoriteDao(super.db);

  static const String _table = 'favorites';

  /// Adds a favourite (idempotent thanks to the unique index).
  Future<void> add(String userId, RefType refType, int refId) async {
    await db.insert(
      _table,
      <String, Object?>{
        'user_id': userId,
        'ref_type': refType.wire,
        'ref_id': refId,
        'created_at': AppDateUtils.nowUtcIso(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Removes a favourite.
  Future<void> remove(String userId, RefType refType, int refId) async {
    await db.delete(
      _table,
      where: 'user_id = ? AND ref_type = ? AND ref_id = ?',
      whereArgs: <Object?>[userId, refType.wire, refId],
    );
  }

  /// Whether an item is favourited.
  Future<bool> isFavorite(String userId, RefType refType, int refId) async {
    final int count = await countRows(
      _table,
      where: 'user_id = ? AND ref_type = ? AND ref_id = ?',
      whereArgs: <Object?>[userId, refType.wire, refId],
    );
    return count > 0;
  }

  /// One page of favourites, newest first.
  Future<List<Favorite>> page(
    String userId, {
    RefType? refType,
    int limit = 20,
    int offset = 0,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: refType == null ? 'user_id = ?' : 'user_id = ? AND ref_type = ?',
      whereArgs: refType == null
          ? <Object?>[userId]
          : <Object?>[userId, refType.wire],
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Favorite.fromMap).toList(growable: false);
  }

  /// Number of favourites (optionally filtered by type).
  Future<int> count(String userId, {RefType? refType}) => countRows(
        _table,
        where: refType == null
            ? 'user_id = ?'
            : 'user_id = ? AND ref_type = ?',
        whereArgs: refType == null
            ? <Object?>[userId]
            : <Object?>[userId, refType.wire],
      );
}
