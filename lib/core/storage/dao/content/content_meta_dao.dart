/// Read-only DAO for `content_metadata`.
///
/// **SELECT-only** (docs/ARCHITECTURE-v0.1.md §4.1).
library;

import 'package:ielts_free/core/models/content_metadata.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';

/// Queries content-package metadata.
class ContentMetaDao extends BaseDao {
  ContentMetaDao(super.db);

  /// The active content package, or `null` when none is marked active.
  Future<ContentMetadata?> active() async {
    final rows = await db.query(
      'content_metadata',
      where: 'is_active = ?',
      whereArgs: <Object?>[1],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return ContentMetadata.fromMap(rows.first);
  }

  /// All metadata rows, newest first.
  Future<List<ContentMetadata>> all() async {
    final rows = await db.query('content_metadata', orderBy: 'id DESC');
    return rows.map(ContentMetadata.fromMap).toList(growable: false);
  }
}
