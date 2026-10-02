/// Reading question (content database, read-only).
///
/// Maps the `reading_questions` table (docs/ARCHITECTURE-v0.1.md §4.2). Every
/// question carries the full explanation bundle required by BRIEF §19:
/// `correctAnswer / evidence / keywords / synonyms / logic / explanation`.
library;

import 'package:ielts_free/core/models/enums/question_type.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/models/reading_option.dart';

/// A single reading question with its explanation.
class ReadingQuestion {
  const ReadingQuestion({
    required this.id,
    required this.passageId,
    required this.orderIndex,
    required this.questionType,
    required this.prompt,
    required this.correctAnswer,
    this.evidence,
    this.keywords = const <String>[],
    this.synonyms = const <List<String>>[],
    this.logic,
    this.explanation,
    this.skill,
    this.difficulty = 3,
    this.options = const <ReadingOption>[],
  });

  /// `reading_questions.id`.
  final int id;

  /// Owning passage id.
  final int passageId;

  /// 1-based position within the passage.
  final int orderIndex;

  /// The question format.
  final QuestionType questionType;

  /// The question text.
  final String prompt;

  /// The correct answer (canonical form).
  final String correctAnswer;

  /// Verbatim excerpt from the passage that proves the answer (BRIEF §19).
  final String? evidence;

  /// Keywords to locate / understand the answer.
  final List<String> keywords;

  /// Synonym pairs `[source, paraphrase]` demonstrating the paraphrase (BRIEF §19).
  final List<List<String>> synonyms;

  /// The reasoning step that links evidence to answer.
  final String? logic;

  /// Full explanation shown after submission.
  final String? explanation;

  /// The reading skill exercised.
  final SkillType? skill;

  /// Difficulty 1..5.
  final int difficulty;

  /// Selectable options.
  ///
  /// **Not a column**: options live in `reading_options` and are attached by the
  /// repository (`ReadingDao.loadOptions`) for choice-style questions.
  final List<ReadingOption> options;

  /// Builds a [ReadingQuestion] from a database row / JSON object.
  factory ReadingQuestion.fromMap(Map<String, Object?> map) => ReadingQuestion(
        id: intOrDefault(map['id'], 0),
        passageId: intOrDefault(map['passage_id'], 0),
        orderIndex: intOrDefault(map['order_index'], 0),
        questionType: QuestionType.fromWire(asString(map['question_type'])),
        prompt: asString(map['prompt']) ?? '',
        correctAnswer: asString(map['correct_answer']) ?? '',
        evidence: asString(map['evidence']),
        keywords: decodeStringList(map['keywords']),
        synonyms: decodeStringMatrix(map['synonyms']),
        logic: asString(map['logic']),
        explanation: asString(map['explanation']),
        skill: SkillType.maybeFromWire(asString(map['skill'])),
        difficulty: intOrDefault(map['difficulty'], 3),
      );

  /// Returns a copy with [options] attached.
  ReadingQuestion withOptions(List<ReadingOption> options) => ReadingQuestion(
        id: id,
        passageId: passageId,
        orderIndex: orderIndex,
        questionType: questionType,
        prompt: prompt,
        correctAnswer: correctAnswer,
        evidence: evidence,
        keywords: keywords,
        synonyms: synonyms,
        logic: logic,
        explanation: explanation,
        skill: skill,
        difficulty: difficulty,
        options: options,
      );

  /// Serialises to a database row map (JSON-encoded array columns).
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'passage_id': passageId,
        'order_index': orderIndex,
        'question_type': questionType.wire,
        'prompt': prompt,
        'correct_answer': correctAnswer,
        'evidence': evidence,
        'keywords': encodeStringList(keywords),
        'synonyms': encodeStringMatrix(synonyms),
        'logic': logic,
        'explanation': explanation,
        'skill': skill?.wire,
        'difficulty': difficulty,
      };
}
