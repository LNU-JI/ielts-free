/// A local note (notes table).
///
/// Notes are always stored locally and never uploaded (docs/BRIEF.md §40).
library;

import 'package:ielts_free/core/models/enums/ref_type.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// A user note attached to a content item.
class Note {
  const Note({
    this.id,
    this.userId,
    this.refType,
    this.refId,
    this.content,
    this.createdAt,
    this.updatedAt,
  });

  /// `notes.id`.
  final int? id;

  /// Owning user id.
  final String? userId;

  /// What the note is attached to.
  final RefType? refType;

  /// The referenced item id.
  final int? refId;

  /// The note body.
  final String? content;

  /// Creation timestamp (UTC).
  final DateTime? createdAt;

  /// Last-update timestamp (UTC).
  final DateTime? updatedAt;

  /// Builds a [Note] from a database row / JSON object.
  factory Note.fromMap(Map<String, Object?> map) => Note(
        id: asInt(map['id']),
        userId: asString(map['user_id']),
        refType: RefType.maybeFromWire(asString(map['ref_type'])),
        refId: asInt(map['ref_id']),
        content: asString(map['content']),
        createdAt: AppDateUtils.parseUtcIso(asString(map['created_at'])),
        updatedAt: AppDateUtils.parseUtcIso(asString(map['updated_at'])),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'ref_type': refType?.wire,
        'ref_id': refId,
        'content': content,
        'created_at':
            createdAt == null ? null : AppDateUtils.toUtcIso(createdAt!),
        'updated_at':
            updatedAt == null ? null : AppDateUtils.toUtcIso(updatedAt!),
      };
}
