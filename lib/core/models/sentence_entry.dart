/// A bookmarked sentence (sentence_book table).
///
/// Hard-to-hear sentences kept for repeat dictation and shadowing. Shared by
/// listening and reading; [sourceType] says which module it came from
/// (lib/core/database/migrations.dart, step 3). The unique index
/// `idx_sb_source(user_id, source_type, source_id)` makes bookmarking
/// idempotent.
library;

import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// One sentence in the sentence book.
class SentenceEntry {
  const SentenceEntry({
    this.id,
    required this.userId,
    required this.sourceType,
    required this.sourceId,
    this.sectionId,
    required this.text,
    this.translation,
    this.note,
    this.reviewCount = 0,
    this.mastered = false,
    required this.createdAt,
  });

  /// `sentence_book.id`.
  final int? id;

  /// Owning user id (NOT NULL).
  final String userId;

  /// Source module, e.g. `LISTENING` / `READING` (NOT NULL).
  final String sourceType;

  /// The cue / question id inside the source (NOT NULL).
  final int sourceId;

  /// Owning listening section, when the source is a listening cue.
  final int? sectionId;

  /// The sentence text.
  final String text;

  /// Chinese translation.
  final String? translation;

  /// A personal note.
  final String? note;

  /// How many times the sentence has been reviewed.
  final int reviewCount;

  /// Whether the sentence has been mastered.
  final bool mastered;

  /// When it was bookmarked (UTC).
  final DateTime createdAt;

  /// Builds a [SentenceEntry] from a database row / JSON object.
  factory SentenceEntry.fromMap(Map<String, Object?> map) => SentenceEntry(
        id: asInt(map['id']),
        userId: asString(map['user_id']) ?? '',
        sourceType: asString(map['source_type']) ?? '',
        sourceId: intOrDefault(map['source_id'], 0),
        sectionId: asInt(map['section_id']),
        text: asString(map['text']) ?? '',
        translation: asString(map['translation']),
        note: asString(map['note']),
        reviewCount: intOrDefault(map['review_count'], 0),
        mastered: asBool(map['mastered']),
        createdAt: AppDateUtils.parseUtcIso(asString(map['created_at'])) ??
            DateTime.now().toUtc(),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'source_type': sourceType,
        'source_id': sourceId,
        'section_id': sectionId,
        'text': text,
        'translation': translation,
        'note': note,
        'review_count': reviewCount,
        'mastered': mastered ? 1 : 0,
        'created_at': AppDateUtils.toUtcIso(createdAt),
      };
}
