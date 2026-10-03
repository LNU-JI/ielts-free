/// Speaking topic (content database, read-only).
///
/// Maps the `speaking_topics` table (content_pipeline/schema.sql).
///
/// A topic bundles the cue card (Part 2) and the timed speaking window. Its
/// questions live in `speaking_questions` and are attached by the repository
/// for the practice screen (see [questions]).
library;

import 'package:ielts_free/core/models/enums/speaking_part.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/models/speaking_question.dart';

/// One IELTS Speaking topic (Part 1–3).
class SpeakingTopic {
  const SpeakingTopic({
    required this.id,
    required this.part,
    required this.topic,
    required this.title,
    this.cueCard,
    this.prepSeconds,
    required this.speakSeconds,
    this.difficulty,
    this.questions = const <SpeakingQuestion>[],
  });

  /// `speaking_topics.id`.
  final int id;

  /// Which part of the test this topic belongs to.
  final SpeakingPart part;

  /// Topic area, e.g. `Hometown`.
  final String topic;

  /// Display title.
  final String title;

  /// The cue card text (Part 2 only).
  final String? cueCard;

  /// Preparation time in seconds; falls back to the part default when unset.
  final int? prepSeconds;

  /// Suggested speaking time in seconds.
  final int speakSeconds;

  /// Difficulty 1–5.
  final int? difficulty;

  /// The questions of this topic.
  ///
  /// **Not a column**: questions live in `speaking_questions` and are attached
  /// by the repository (`SpeakingDao.questionsForTopic`).
  final List<SpeakingQuestion> questions;

  /// Preparation time, falling back to the part default when unset.
  int get effectivePrepSeconds => prepSeconds ?? part.prepSeconds;

  /// Chinese label for the part, e.g. `Part 1`.
  String get partLabel => part.label;

  /// Whether this topic carries a cue card.
  bool get hasCueCard => cueCard != null && cueCard!.isNotEmpty;

  /// Returns a copy with [questions] attached.
  SpeakingTopic withQuestions(List<SpeakingQuestion> questions) =>
      SpeakingTopic(
        id: id,
        part: part,
        topic: topic,
        title: title,
        cueCard: cueCard,
        prepSeconds: prepSeconds,
        speakSeconds: speakSeconds,
        difficulty: difficulty,
        questions: questions,
      );

  /// Builds a [SpeakingTopic] from a database row / JSON object.
  factory SpeakingTopic.fromMap(Map<String, Object?> map) => SpeakingTopic(
        id: intOrDefault(map['id'], 0),
        part: SpeakingPart.fromWire(asInt(map['part'])),
        topic: asString(map['topic']) ?? '',
        title: asString(map['title']) ?? '',
        cueCard: asString(map['cue_card']),
        prepSeconds: asInt(map['prep_seconds']),
        speakSeconds: intOrDefault(map['speak_seconds'], 0),
        difficulty: asInt(map['difficulty']),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'part': part.wire,
        'topic': topic,
        'title': title,
        'cue_card': cueCard,
        'prep_seconds': prepSeconds,
        'speak_seconds': speakSeconds,
        'difficulty': difficulty,
      };
}
