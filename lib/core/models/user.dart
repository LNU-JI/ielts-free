/// The user record (users table).
///
/// V0.1 has a single guest account: `local_user` (docs/BRIEF.md §11). No cloud
/// account, no login.
library;

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// A user row.
class User {
  const User({
    required this.id,
    required this.createdAt,
    this.updatedAt,
  });

  /// `users.id`.
  final String id;

  /// Creation timestamp (UTC).
  final DateTime createdAt;

  /// Last-update timestamp (UTC).
  final DateTime? updatedAt;

  /// The default guest user (`local_user`, BRIEF §11).
  factory User.localUser({DateTime? now}) => User(
        id: AppConstants.localUserId,
        createdAt: (now ?? DateTime.now()).toUtc(),
      );

  /// Builds a [User] from a database row / JSON object.
  factory User.fromMap(Map<String, Object?> map) => User(
        id: asString(map['id']) ?? AppConstants.localUserId,
        createdAt: AppDateUtils.parseUtcIso(asString(map['created_at'])) ??
            DateTime.now().toUtc(),
        updatedAt: AppDateUtils.parseUtcIso(asString(map['updated_at'])),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'created_at': AppDateUtils.toUtcIso(createdAt),
        'updated_at': updatedAt == null ? null : AppDateUtils.toUtcIso(updatedAt!),
      };
}
