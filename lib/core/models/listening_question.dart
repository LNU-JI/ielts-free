/// Listening question (content database, read-only).
///
/// Maps the `listening_questions` table (content_pipeline/schema.sql).
library;

import 'package:ielts_free/core/models/enums/listening_question_type.dart';
import 'package:ielts_free/core/models/json_utils.dart';

/// A distractor: a tempting wrong answer and why it is wrong.
///
/// Stored in `listening_questions.distractors` as a JSON array of objects with
/// `option` and `reason` keys.
class ListeningDistractor {
  const ListeningDistractor({required this.option, required this.reason});

  /// The tempting but incorrect option.
  final String option;

  /// Why it is wrong (usually "the audio says X, not Y").
  final String reason;

  /// Builds a [ListeningDistractor] from a decoded JSON object.
  factory ListeningDistractor.fromMap(Map<String, Object?> map) =>
      ListeningDistractor(
        option: asString(map['option']) ?? '',
        reason: asString(map['reason']) ?? '',
      );
}

/// One question attached to a listening section.
class ListeningQuestion {
  const ListeningQuestion({
    required this.id,
    required this.sectionId,
    required this.orderIndex,
    required this.type,
    required this.prompt,
    this.options = const <String>[],
    required this.answer,
    this.alternatives = const <String>[],
    this.evidenceCueId,
    this.explanation,
    this.distractors = const <ListeningDistractor>[],
  });

  /// `listening_questions.id`.
  final int id;

  /// Owning section id.
  final int sectionId;

  /// Order inside the section (1-based).
  final int orderIndex;

  /// Question format.
  final ListeningQuestionType type;

  /// Question text as shown to the learner.
  final String prompt;

  /// Selectable options for choice-style questions.
  final List<String> options;

  /// The correct answer.
  final String answer;

  /// Other accepted spellings / phrasings.
  final List<String> alternatives;

  /// The cue that contains the answer — used by the evidence step.
  final int? evidenceCueId;

  /// Why this is the answer.
  final String? explanation;

  /// Tempting wrong options and why each is wrong.
  final List<ListeningDistractor> distractors;

  /// Every string that should be graded as correct.
  List<String> get acceptedAnswers =>
      <String>[answer, ...alternatives].where((String a) => a.isNotEmpty).toList();

  /// Builds a [ListeningQuestion] from a database row / JSON object.
  factory ListeningQuestion.fromMap(Map<String, Object?> map) =>
      ListeningQuestion(
        id: intOrDefault(map['id'], 0),
        sectionId: intOrDefault(map['section_id'], 0),
        orderIndex: intOrDefault(map['order_index'], 0),
        type: ListeningQuestionType.fromWire(asString(map['question_type'])),
        prompt: asString(map['prompt']) ?? '',
        options: decodeStringList(map['options']),
        answer: asString(map['answer']) ?? '',
        alternatives: decodeStringList(map['alternatives']),
        evidenceCueId: asInt(map['evidence_cue_id']),
        explanation: asString(map['explanation']),
        distractors: decodeMapList(map['distractors'])
            .map(ListeningDistractor.fromMap)
            .toList(growable: false),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'section_id': sectionId,
        'order_index': orderIndex,
        'question_type': type.wire,
        'prompt': prompt,
        'options': encodeStringList(options),
        'answer': answer,
        'alternatives': encodeStringList(alternatives),
        'evidence_cue_id': evidenceCueId,
        'explanation': explanation,
        'distractors': encodeMapList(<Map<String, Object?>>[
          for (final ListeningDistractor d in distractors)
            <String, Object?>{'option': d.option, 'reason': d.reason},
        ]),
      };
}
