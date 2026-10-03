/// Writing phrase (content database, read-only).
///
/// Maps the `writing_phrases` table (content_pipeline/schema.sql).
///
/// Sentence patterns and linking phrases the learner can collect into the
/// phrase book while writing (see `phrase_book` in the user database).
library;

import 'package:ielts_free/core/models/json_utils.dart';

/// One reusable writing phrase.
class WritingPhrase {
  const WritingPhrase({
    required this.id,
    required this.category,
    this.task,
    required this.phrase,
    this.meaningCn,
    this.example,
    this.band,
  });

  /// `writing_phrases.id`.
  final int id;

  /// Functional category, e.g. `introduction` / `linking` / `conclusion`.
  final String category;

  /// Task this phrase fits (1 or 2); `null` means either.
  final int? task;

  /// The phrase itself.
  final String phrase;

  /// Chinese meaning / usage note.
  final String? meaningCn;

  /// An example sentence using the phrase.
  final String? example;

  /// Target band label.
  final String? band;

  /// Whether the phrase is tied to a specific task.
  bool get hasTask => task != null;

  /// Builds a [WritingPhrase] from a database row / JSON object.
  factory WritingPhrase.fromMap(Map<String, Object?> map) => WritingPhrase(
        id: intOrDefault(map['id'], 0),
        category: asString(map['category']) ?? '',
        task: asInt(map['task']),
        phrase: asString(map['phrase']) ?? '',
        meaningCn: asString(map['meaning_cn']),
        example: asString(map['example']),
        band: asString(map['band']),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'category': category,
        'task': task,
        'phrase': phrase,
        'meaning_cn': meaningCn,
        'example': example,
        'band': band,
      };
}
