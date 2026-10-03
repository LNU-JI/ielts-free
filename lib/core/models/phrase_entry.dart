/// A bookmarked phrase (phrase_book table).
///
/// Sentence patterns collected while writing. [phraseId] links back to
/// `writing_phrases` in the content database when the phrase came from the
/// library; a phrase typed by hand has no id. Deduplication is by
/// `(user_id, phrase)` — the table has no unique index, so the DAO enforces it
/// (lib/core/database/migrations.dart, step 3).
library;

import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// One phrase in the phrase book.
class PhraseEntry {
  const PhraseEntry({
    this.id,
    required this.userId,
    this.phraseId,
    required this.phrase,
    this.meaningCn,
    this.category,
    this.source,
    required this.createdAt,
  });

  /// `phrase_book.id`.
  final int? id;

  /// Owning user id (NOT NULL).
  final String userId;

  /// The content phrase this came from, when it was collected from the library.
  final int? phraseId;

  /// The phrase text (NOT NULL).
  final String phrase;

  /// Chinese meaning / usage note.
  final String? meaningCn;

  /// Functional category, mirroring `writing_phrases.category`.
  final String? category;

  /// Free-form provenance, e.g. `writing` / `manual`.
  final String? source;

  /// When it was collected (UTC).
  final DateTime createdAt;

  /// Whether the phrase links back to a content-library phrase.
  bool get hasPhraseId => phraseId != null;

  /// Builds a [PhraseEntry] from a database row / JSON object.
  factory PhraseEntry.fromMap(Map<String, Object?> map) => PhraseEntry(
        id: asInt(map['id']),
        userId: asString(map['user_id']) ?? '',
        phraseId: asInt(map['phrase_id']),
        phrase: asString(map['phrase']) ?? '',
        meaningCn: asString(map['meaning_cn']),
        category: asString(map['category']),
        source: asString(map['source']),
        createdAt: AppDateUtils.parseUtcIso(asString(map['created_at'])) ??
            DateTime.now().toUtc(),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'phrase_id': phraseId,
        'phrase': phrase,
        'meaning_cn': meaningCn,
        'category': category,
        'source': source,
        'created_at': AppDateUtils.toUtcIso(createdAt),
      };
}
