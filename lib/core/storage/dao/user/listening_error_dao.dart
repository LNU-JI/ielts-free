/// DAO for `listening_error_log`.
///
/// The write side of the intensive-listening loop: every missed answer is
/// appended with its [ListeningErrorType], and the aggregate powers the
/// "what should I drill next" screen.
library;

import 'package:ielts_free/core/models/enums/listening_error_type.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/models/listening_error.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';

/// Reads and writes the listening error log.
class ListeningErrorDao extends BaseDao {
  ListeningErrorDao(super.db);

  static const String _table = 'listening_error_log';

  /// Inserts one error and returns its new id.
  Future<int> insert(ListeningError error) async {
    final Map<String, Object?> map = error.toMap()..remove('id');
    return db.insert(_table, map);
  }

  /// Errors logged for one section, newest first.
  Future<List<ListeningError>> forSection(
    String userId,
    int sectionId,
  ) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND section_id = ?',
      whereArgs: <Object?>[userId, sectionId],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(ListeningError.fromMap).toList(growable: false);
  }

  /// Number of errors logged for one section.
  Future<int> countForSection(String userId, int sectionId) => countRows(
        _table,
        where: 'user_id = ? AND section_id = ?',
        whereArgs: <Object?>[userId, sectionId],
      );

  /// Errors grouped by [ListeningErrorType], optionally scoped to one section.
  ///
  /// Unknown `error_type` values in the table are ignored rather than mapped to
  /// a default, so the statistics never silently invent a category.
  Future<Map<ListeningErrorType, int>> countByType(
    String userId, {
    int? sectionId,
  }) async {
    final bool scoped = sectionId != null;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT error_type, COUNT(*) AS c FROM $_table '
      'WHERE user_id = ?${scoped ? ' AND section_id = ?' : ''} '
      'GROUP BY error_type',
      scoped ? <Object?>[userId, sectionId] : <Object?>[userId],
    );
    final Map<ListeningErrorType, int> result = <ListeningErrorType, int>{};
    for (final Map<String, Object?> row in rows) {
      final ListeningErrorType? type =
          ListeningErrorType.maybeFromWire(asString(row['error_type']));
      if (type == null) {
        continue;
      }
      result[type] = asInt(row['c']) ?? 0;
    }
    return result;
  }

  /// Deletes every error logged for one section (a fresh retry of that drill).
  Future<void> clearForSection(String userId, int sectionId) async {
    await db.delete(
      _table,
      where: 'user_id = ? AND section_id = ?',
      whereArgs: <Object?>[userId, sectionId],
    );
  }
}
