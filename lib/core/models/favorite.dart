/// A favourite (favorites table).
///
/// Favourites can point at any content item (docs/BRIEF.md §39).
library;

import 'package:ielts_free/core/models/enums/ref_type.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// A `(ref_type, ref_id)` favourite for a user.
class Favorite {
  const Favorite({
    this.id,
    this.userId,
    this.refType,
    this.refId,
    this.createdAt,
  });

  /// `favorites.id`.
  final int? id;

  /// Owning user id.
  final String? userId;

  /// What is favourited.
  final RefType? refType;

  /// The referenced item id.
  final int? refId;

  /// Creation timestamp (UTC).
  final DateTime? createdAt;

  /// Builds a [Favorite] from a database row / JSON object.
  factory Favorite.fromMap(Map<String, Object?> map) => Favorite(
        id: asInt(map['id']),
        userId: asString(map['user_id']),
        refType: RefType.maybeFromWire(asString(map['ref_type'])),
        refId: asInt(map['ref_id']),
        createdAt: AppDateUtils.parseUtcIso(asString(map['created_at'])),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'ref_type': refType?.wire,
        'ref_id': refId,
        'created_at':
            createdAt == null ? null : AppDateUtils.toUtcIso(createdAt!),
      };
}
