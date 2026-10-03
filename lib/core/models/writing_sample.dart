/// Writing sample essay (content database, read-only).
///
/// Maps the `writing_samples` table (content_pipeline/schema.sql).
///
/// A banded model essay for a task, plus the paragraph outline it follows and
/// inline annotations explaining *why* each move earns marks.
library;

import 'package:ielts_free/core/models/json_utils.dart';

/// One paragraph of a sample essay's outline.
///
/// Stored in `writing_samples.outline` as a JSON array of objects with
/// `section` and `content` keys.
class WritingOutlinePoint {
  const WritingOutlinePoint({required this.section, required this.content});

  /// Paragraph role, e.g. `Introduction` / `Overview` / `Body paragraph 1`.
  final String section;

  /// What the paragraph should cover.
  final String content;

  /// Builds a [WritingOutlinePoint] from a decoded JSON object.
  factory WritingOutlinePoint.fromMap(Map<String, Object?> map) =>
      WritingOutlinePoint(
        section: asString(map['section']) ?? '',
        content: asString(map['content']) ?? '',
      );

  /// Serialises to a JSON-ready map.
  Map<String, Object?> toMap() => <String, Object?>{
        'section': section,
        'content': content,
      };
}

/// One inline annotation on a sample essay.
///
/// Stored in `writing_samples.annotations` as a JSON array of objects with
/// `sentence`, `comment` and `band` keys.
class WritingAnnotation {
  const WritingAnnotation({
    required this.sentence,
    required this.comment,
    this.band,
  });

  /// The quoted sentence being annotated.
  final String sentence;

  /// Why this sentence earns marks.
  final String comment;

  /// Band this move targets, e.g. `7+`.
  final String? band;

  /// Builds a [WritingAnnotation] from a decoded JSON object.
  factory WritingAnnotation.fromMap(Map<String, Object?> map) => WritingAnnotation(
        sentence: asString(map['sentence']) ?? '',
        comment: asString(map['comment']) ?? '',
        band: asString(map['band']),
      );

  /// Serialises to a JSON-ready map.
  Map<String, Object?> toMap() => <String, Object?>{
        'sentence': sentence,
        'comment': comment,
        'band': band,
      };
}

/// One model essay for a writing task.
class WritingSample {
  const WritingSample({
    required this.id,
    required this.taskId,
    this.band,
    required this.essay,
    this.outline = const <WritingOutlinePoint>[],
    this.annotations = const <WritingAnnotation>[],
  });

  /// `writing_samples.id`.
  final int id;

  /// Owning task id.
  final int taskId;

  /// The band this essay is written to, e.g. `7.0` / `8.0`.
  final String? band;

  /// The full model essay.
  final String essay;

  /// Paragraph-by-paragraph outline.
  final List<WritingOutlinePoint> outline;

  /// Inline annotations explaining the essay's moves.
  final List<WritingAnnotation> annotations;

  /// Whether a band label is available.
  bool get hasBand => band != null && band!.isNotEmpty;

  /// Builds a [WritingSample] from a database row / JSON object.
  factory WritingSample.fromMap(Map<String, Object?> map) => WritingSample(
        id: intOrDefault(map['id'], 0),
        taskId: intOrDefault(map['task_id'], 0),
        band: asString(map['band']),
        essay: asString(map['essay']) ?? '',
        outline: decodeMapList(map['outline'])
            .map(WritingOutlinePoint.fromMap)
            .toList(growable: false),
        annotations: decodeMapList(map['annotations'])
            .map(WritingAnnotation.fromMap)
            .toList(growable: false),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'task_id': taskId,
        'band': band,
        'essay': essay,
        'outline': encodeMapList(<Map<String, Object?>>[
          for (final WritingOutlinePoint p in outline) p.toMap(),
        ]),
        'annotations': encodeMapList(<Map<String, Object?>>[
          for (final WritingAnnotation a in annotations) a.toMap(),
        ]),
      };
}
