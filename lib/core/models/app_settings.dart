/// A key/value app setting (app_settings table).
///
/// Settings are stored as `(user_id, key, value)` rows so new options can be
/// added without a migration (docs/BRIEF.md §42).
library;

import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// Well-known setting keys.
abstract final class SettingKeys {
  const SettingKeys._();

  static const String themeMode = 'theme_mode';
  static const String fontScale = 'font_scale';
  static const String soundEnabled = 'sound_enabled';
  static const String notificationsEnabled = 'notifications_enabled';
  static const String dailyTargetMinutes = 'daily_target_minutes';
  static const String onboardingCompleted = 'onboarding_completed';
}

/// One settings row.
class AppSettings {
  const AppSettings({
    this.id,
    this.userId,
    required this.key,
    this.value,
    this.updatedAt,
  });

  /// `app_settings.id`.
  final int? id;

  /// Owning user id.
  final String? userId;

  /// Setting key.
  final String key;

  /// Setting value (string-encoded).
  final String? value;

  /// Last-update timestamp (UTC).
  final DateTime? updatedAt;

  /// Reads [value] as a boolean, or [fallback].
  bool boolValue({bool fallback = false}) => asBool(value, fallback: fallback);

  /// Reads [value] as an int, or [fallback].
  int intValue({int fallback = 0}) => intOrDefault(value, fallback);

  /// Reads [value] as a double, or [fallback].
  double doubleValue({double fallback = 0}) =>
      doubleOrDefault(value, fallback);

  /// Builds an [AppSettings] from a database row / JSON object.
  factory AppSettings.fromMap(Map<String, Object?> map) => AppSettings(
        id: asInt(map['id']),
        userId: asString(map['user_id']),
        key: asString(map['key']) ?? '',
        value: asString(map['value']),
        updatedAt: AppDateUtils.parseUtcIso(asString(map['updated_at'])),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'key': key,
        'value': value,
        'updated_at':
            updatedAt == null ? null : AppDateUtils.toUtcIso(updatedAt!),
      };
}
