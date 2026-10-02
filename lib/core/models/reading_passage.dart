/// Reading passage (content database, read-only).
///
/// Maps the `reading_passages` table (docs/ARCHITECTURE-v0.1.md §4.2).
library;

import 'package:ielts_free/core/models/json_utils.dart';

/// A single reading passage.
class ReadingPassage {
  const ReadingPassage({
    required this.id,
    required this.title,
    this.topic,
    this.difficulty = 3,
    this.band,
    this.readingTimeSec,
    required this.passage,
    this.skills = const <String>[],
  });

  /// `reading_passages.id`.
  final int id;

  /// Passage title.
  final String title;

  /// Topic area.
  final String? topic;

  /// Difficulty 1..5.
  final int difficulty;

  /// Estimated band label, e.g. `6.0-7.0`.
  final String? band;

  /// Suggested reading time in seconds.
  final int? readingTimeSec;

  /// The full passage text.
  final String passage;

  /// Skills exercised (JSON array of `SkillType` wire values).
  final List<String> skills;

  /// Builds a [ReadingPassage] from a database row / JSON object.
  factory ReadingPassage.fromMap(Map<String, Object?> map) => ReadingPassage(
        id: intOrDefault(map['id'], 0),
        title: asString(map['title']) ?? '',
        topic: asString(map['topic']),
        difficulty: intOrDefault(map['difficulty'], 3),
        band: asString(map['band']),
        readingTimeSec: asInt(map['reading_time_sec']),
        passage: asString(map['passage']) ?? '',
        skills: decodeStringList(map['skills']),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'topic': topic,
        'difficulty': difficulty,
        'band': band,
        'reading_time_sec': readingTimeSec,
        'passage': passage,
        'skills': encodeStringList(skills),
      };
}
