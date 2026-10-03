/// Listening section (content database, read-only).
///
/// Maps the `listening_sections` table (content_pipeline/schema.sql).
///
/// Audio is **not** shipped: the app synthesises it on device from the
/// section's [ListeningCue] rows using the platform TTS engine, so the content
/// pack stays text-only and the app stays fully offline.
library;

import 'package:ielts_free/core/models/json_utils.dart';

/// One IELTS Listening section (Part 1–4).
class ListeningSection {
  const ListeningSection({
    required this.id,
    required this.part,
    required this.title,
    this.scene,
    this.accent,
    this.difficulty,
    this.overview,
    this.skills = const <String>[],
  });

  /// `listening_sections.id`.
  final int id;

  /// IELTS Listening part, 1–4.
  final int part;

  /// Section title.
  final String title;

  /// Situation, e.g. 租房咨询 / 学术讲座.
  final String? scene;

  /// Target accent for the synthesised voice, e.g. `british`.
  final String? accent;

  /// Difficulty 1–5.
  final int? difficulty;

  /// One-paragraph Chinese overview of what the section is about.
  final String? overview;

  /// Skill tags.
  final List<String> skills;

  /// Chinese label for the part, e.g. `Part 1`.
  String get partLabel => 'Part $part';

  /// Builds a [ListeningSection] from a database row / JSON object.
  factory ListeningSection.fromMap(Map<String, Object?> map) =>
      ListeningSection(
        id: intOrDefault(map['id'], 0),
        part: intOrDefault(map['part'], 1),
        title: asString(map['title']) ?? '',
        scene: asString(map['scene']),
        accent: asString(map['accent']),
        difficulty: asInt(map['difficulty']),
        overview: asString(map['overview']),
        skills: decodeStringList(map['skills']),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'part': part,
        'title': title,
        'scene': scene,
        'accent': accent,
        'difficulty': difficulty,
        'overview': overview,
        'skills': encodeStringList(skills),
      };
}
