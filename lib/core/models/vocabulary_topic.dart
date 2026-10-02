/// Topic tag linking a vocabulary item to an IELTS topic area.
///
/// Maps the `vocabulary_topics` table (docs/ARCHITECTURE-v0.1.md §4.2). One
/// vocabulary item may carry several topics (Education / Technology / …).
library;

import 'package:ielts_free/core/models/json_utils.dart';

/// A `(vocabulary_id, topic)` pair.
class VocabularyTopic {
  const VocabularyTopic({
    this.id,
    required this.vocabularyId,
    required this.topic,
  });

  /// `vocabulary_topics.id`.
  final int? id;

  /// Owning vocabulary id.
  final int vocabularyId;

  /// Topic name, e.g. `Environment`.
  final String topic;

  /// Builds a [VocabularyTopic] from a database row / JSON object.
  factory VocabularyTopic.fromMap(Map<String, Object?> map) => VocabularyTopic(
        id: asInt(map['id']),
        vocabularyId: intOrDefault(map['vocabulary_id'], 0),
        topic: asString(map['topic']) ?? '',
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'vocabulary_id': vocabularyId,
        'topic': topic,
      };
}
