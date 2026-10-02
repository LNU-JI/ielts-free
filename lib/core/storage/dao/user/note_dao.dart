/// DAO for `notes`.
library;


import 'package:ielts_free/core/models/enums/ref_type.dart';
import 'package:ielts_free/core/models/note.dart';
import 'package:ielts_free/core/storage/dao/base_dao.dart';

/// Reads and writes local notes.
class NoteDao extends BaseDao {
  NoteDao(super.db);

  static const String _table = 'notes';

  /// Inserts [note] or updates it when [Note.id] is set. Returns the row id.
  Future<int> upsert(Note note) async {
    final int? id = note.id;
    if (id != null) {
      await db.update(
        _table,
        note.toMap(),
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      return id;
    }
    final Map<String, Object?> map = note.toMap()..remove('id');
    return db.insert(_table, map);
  }

  /// Notes attached to one item, newest first.
  Future<List<Note>> forRef(
    String userId,
    RefType refType,
    int refId,
  ) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ? AND ref_type = ? AND ref_id = ?',
      whereArgs: <Object?>[userId, refType.wire, refId],
      orderBy: 'updated_at DESC, id DESC',
    );
    return rows.map(Note.fromMap).toList(growable: false);
  }

  /// One page of notes for [userId], newest first.
  Future<List<Note>> page(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      _table,
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      orderBy: 'updated_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Note.fromMap).toList(growable: false);
  }

  /// Deletes one note.
  Future<void> delete(int id) async {
    await db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id]);
  }
}
