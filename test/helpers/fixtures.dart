/// Shared test fixtures for the adaptive-engine unit tests.
///
/// Keeping the builders here means every algorithm test constructs its inputs
/// the same way, so a change to a value object's shape breaks in one place
/// (docs/ARCHITECTURE-v0.1.md §5).
library;

import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/vocabulary.dart';
import 'package:ielts_free/core/services/adaptive/adaptive_models.dart';

/// Builds an [AnswerSample] for the adaptive algorithms.
AnswerSample answerSample({
  required bool correct,
  required DateTime at,
  int difficulty = 3,
  SkillType? skill,
}) =>
    AnswerSample(
      isCorrect: correct,
      difficulty: difficulty,
      answeredAt: at,
      skill: skill,
    );

/// Builds a minimal [Vocabulary] item.
Vocabulary vocabWord({
  int? id,
  required String word,
  String meaningCn = '释义',
  int difficulty = 3,
  List<String> synonyms = const <String>[],
  List<String> collocations = const <String>[],
  List<VocabularyExample> examples = const <VocabularyExample>[],
}) =>
    Vocabulary(
      id: id,
      word: word,
      meaningCn: meaningCn,
      difficulty: difficulty,
      synonyms: synonyms,
      collocations: collocations,
      examples: examples,
    );
