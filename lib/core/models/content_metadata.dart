/// Content-package metadata (content_metadata table).
///
/// Records the imported content version, per-table counts and the SHA256 of the
/// compiled content database (docs/BRIEF.md §74). The same shape is written by
/// `content_pipeline/build_content_db.py` into the content database and by the
/// app into the user database on import.
library;

import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// Metadata describing one content package.
class ContentMetadata {
  const ContentMetadata({
    this.id,
    required this.contentVersion,
    this.appCompatibility,
    this.vocabularyCount = 0,
    this.readingCount = 0,
    this.listeningCount = 0,
    this.writingCount = 0,
    this.speakingCount = 0,
    this.checksum,
    this.importedAt,
    this.isActive = true,
  });

  /// `content_metadata.id`.
  final int? id;

  /// Content package version, e.g. `1.0.0`.
  final String contentVersion;

  /// Compatible app version range.
  final String? appCompatibility;

  /// Number of vocabulary items.
  final int vocabularyCount;

  /// Number of reading passages.
  final int readingCount;

  /// Number of listening items.
  final int listeningCount;

  /// Number of writing prompts.
  final int writingCount;

  /// Number of speaking questions.
  final int speakingCount;

  /// SHA256 of the content database.
  final String? checksum;

  /// Import timestamp (UTC).
  final DateTime? importedAt;

  /// Whether this is the active content package.
  final bool isActive;

  /// Builds a [ContentMetadata] from a database row / JSON object.
  factory ContentMetadata.fromMap(Map<String, Object?> map) => ContentMetadata(
        id: asInt(map['id']),
        contentVersion: asString(map['content_version']) ?? '',
        appCompatibility: asString(map['app_compatibility']),
        vocabularyCount: intOrDefault(map['vocabulary_count'], 0),
        readingCount: intOrDefault(map['reading_count'], 0),
        listeningCount: intOrDefault(map['listening_count'], 0),
        writingCount: intOrDefault(map['writing_count'], 0),
        speakingCount: intOrDefault(map['speaking_count'], 0),
        checksum: asString(map['checksum']),
        importedAt: AppDateUtils.parseUtcIso(asString(map['imported_at'])),
        isActive: asBool(map['is_active'], fallback: true),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'content_version': contentVersion,
        'app_compatibility': appCompatibility,
        'vocabulary_count': vocabularyCount,
        'reading_count': readingCount,
        'listening_count': listeningCount,
        'writing_count': writingCount,
        'speaking_count': speakingCount,
        'checksum': checksum,
        'imported_at':
            importedAt == null ? null : AppDateUtils.toUtcIso(importedAt!),
        'is_active': isActive ? 1 : 0,
      };
}
