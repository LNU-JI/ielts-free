/// Speaking question (content database, read-only).
///
/// Maps the `speaking_questions` table (content_pipeline/schema.sql).
///
/// One question of a topic: the examiner's prompt, an optional Chinese gloss,
/// a model answer, the key phrases worth stealing, and the follow-up probes the
/// examiner may add when the answer is too short.
library;

import 'package:ielts_free/core/models/json_utils.dart';

/// A single question belonging to a speaking topic.
class SpeakingQuestion {
  const SpeakingQuestion({
    required this.id,
    required this.topicId,
    required this.orderIndex,
    required this.question,
    this.questionCn,
    this.sampleAnswer,
    this.keyPhrases = const <String>[],
    this.followUps = const <String>[],
  });

  /// `speaking_questions.id`.
  final int id;

  /// Owning topic id.
  final int topicId;

  /// Order inside the topic (1-based).
  final int orderIndex;

  /// The examiner's question, in English.
  final String question;

  /// Chinese gloss of the question.
  final String? questionCn;

  /// A model answer at the target band.
  final String? sampleAnswer;

  /// High-value phrases to reuse in the answer.
  final List<String> keyPhrases;

  /// Follow-up probes the examiner may ask.
  final List<String> followUps;

  /// Whether a model answer is available.
  bool get hasSampleAnswer => sampleAnswer != null && sampleAnswer!.isNotEmpty;

  /// Builds a [SpeakingQuestion] from a database row / JSON object.
  factory SpeakingQuestion.fromMap(Map<String, Object?> map) =>
      SpeakingQuestion(
        id: intOrDefault(map['id'], 0),
        topicId: intOrDefault(map['topic_id'], 0),
        orderIndex: intOrDefault(map['order_index'], 0),
        question: asString(map['question']) ?? '',
        questionCn: asString(map['question_cn']),
        sampleAnswer: asString(map['sample_answer']),
        keyPhrases: decodeStringList(map['key_phrases']),
        followUps: decodeStringList(map['follow_ups']),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'topic_id': topicId,
        'order_index': orderIndex,
        'question': question,
        'question_cn': questionCn,
        'sample_answer': sampleAnswer,
        'key_phrases': encodeStringList(keyPhrases),
        'follow_ups': encodeStringList(followUps),
      };
}
