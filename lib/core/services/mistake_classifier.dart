/// Classifies a wrong answer into the error taxonomy of docs/BRIEF.md §29.
///
/// The classifier is a pure function: it maps a question's *kind* (a vocabulary
/// practice type or a reading question type) onto the closest [ErrorType]. It is
/// deliberately conservative — when a finer label is not derivable from the
/// content alone, the broadest sensible category is chosen so the mistake queue
/// stays filterable and the priority engine still gets a usable key.
library;

import 'package:ielts_free/core/models/enums/error_type.dart';
import 'package:ielts_free/core/models/enums/question_type.dart';
import 'package:ielts_free/core/services/grading_service.dart';

/// Maps question kinds to [ErrorType]s (BRIEF §29).
abstract final class MistakeClassifier {
  const MistakeClassifier._();

  /// Error type for a vocabulary practice question of [kind].
  ///
  /// - spelling questions → [ErrorType.spelling];
  /// - synonym questions → [ErrorType.synonym];
  /// - collocation questions → [ErrorType.collocation];
  /// - everything else is a word-meaning problem.
  static ErrorType forVocabulary(VocabQuestionKind kind) {
    switch (kind) {
      case VocabQuestionKind.spelling:
        return ErrorType.spelling;
      case VocabQuestionKind.synonymChoice:
        return ErrorType.synonym;
      case VocabQuestionKind.collocationChoice:
        return ErrorType.collocation;
      case VocabQuestionKind.wordToMeaning:
      case VocabQuestionKind.meaningToWord:
      case VocabQuestionKind.multipleChoice:
      case VocabQuestionKind.exampleCloze:
        return ErrorType.wordMeaning;
    }
  }

  /// Error type for a reading question of [type].
  ///
  /// T/F/NG and Y/N/NG failures are overwhelmingly paraphrase (同义替换) failures;
  /// heading matching is a main-idea task; multiple choice is a detail task; the
  /// remaining gap-fill types are treated as locating (定位) problems.
  static ErrorType forReading(QuestionType type) {
    switch (type) {
      case QuestionType.tfng:
      case QuestionType.ynng:
        return ErrorType.readingParaphrase;
      case QuestionType.multipleChoice:
        return ErrorType.readingDetail;
      case QuestionType.matchingHeadings:
        return ErrorType.readingMainIdea;
      case QuestionType.matchingInformation:
        return ErrorType.readingLocating;
      case QuestionType.sentenceCompletion:
      case QuestionType.summaryCompletion:
      case QuestionType.tableCompletion:
      case QuestionType.noteCompletion:
        return ErrorType.readingLocating;
    }
  }
}
