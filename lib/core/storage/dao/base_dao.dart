/// Shared base class for all DAOs.
///
/// A DAO owns a [Database] handle and translates rows to/from models. It never
/// throws to the repository layer beyond sqflite errors, which
/// `error_handler.dart` maps to [Failure]s.
library;

import 'package:sqflite/sqflite.dart';

/// Common helpers for DAOs.
abstract class BaseDao {
  BaseDao(this.db);

  /// The database handle this DAO reads/writes.
  final Database db;

  /// Counts rows in [table] with an optional `where` clause.
  ///
  /// [where] and [whereArgs] must come from trusted, hard-coded SQL fragments —
  /// user input is always bound through `whereArgs`.
  Future<int> countRows(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final String clause = where == null ? '' : 'WHERE $where';
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $table $clause',
      whereArgs,
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
