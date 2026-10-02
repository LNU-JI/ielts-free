/// User profile (user_profile table).
///
/// Holds the display name, the self-declared weakest skill and whether the
/// five-step Onboarding has been completed.
library;

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// A user-profile row.
class UserProfile {
  const UserProfile({
    required this.userId,
    this.displayName,
    this.weakestSkill,
    this.onboardingCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  /// `user_profile.user_id`.
  final String userId;

  /// Display name.
  final String? displayName;

  /// The skill the user self-identified as weakest (Onboarding step 4).
  final SkillType? weakestSkill;

  /// Whether Onboarding finished.
  final bool onboardingCompleted;

  /// Creation timestamp (UTC).
  final DateTime? createdAt;

  /// Last-update timestamp (UTC).
  final DateTime? updatedAt;

  /// The default profile for the guest user (BRIEF §11).
  factory UserProfile.localDefault({DateTime? now}) {
    final DateTime timestamp = (now ?? DateTime.now()).toUtc();
    return UserProfile(
      userId: AppConstants.localUserId,
      displayName: AppConstants.localUserDisplayName,
      onboardingCompleted: false,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  /// Builds a [UserProfile] from a database row / JSON object.
  factory UserProfile.fromMap(Map<String, Object?> map) => UserProfile(
        userId: asString(map['user_id']) ?? AppConstants.localUserId,
        displayName: asString(map['display_name']),
        weakestSkill: SkillType.maybeFromWire(asString(map['weakest_skill'])),
        onboardingCompleted: asBool(map['onboarding_completed']),
        createdAt: AppDateUtils.parseUtcIso(asString(map['created_at'])),
        updatedAt: AppDateUtils.parseUtcIso(asString(map['updated_at'])),
      );

  /// Returns a copy with the given fields replaced.
  UserProfile copyWith({
    String? displayName,
    SkillType? weakestSkill,
    bool? onboardingCompleted,
    DateTime? updatedAt,
  }) =>
      UserProfile(
        userId: userId,
        displayName: displayName ?? this.displayName,
        weakestSkill: weakestSkill ?? this.weakestSkill,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        'user_id': userId,
        'display_name': displayName,
        'weakest_skill': weakestSkill?.wire,
        'onboarding_completed': onboardingCompleted ? 1 : 0,
        'created_at':
            createdAt == null ? null : AppDateUtils.toUtcIso(createdAt!),
        'updated_at':
            updatedAt == null ? null : AppDateUtils.toUtcIso(updatedAt!),
      };
}
