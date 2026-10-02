/// Unit tests for [GradingService] — ARCHITECTURE §5 grading note / BRIEF §17/§19.
///
/// Covers the seven vocabulary kinds, the reading types, the normalisation rules
/// (case, whitespace, full-width, optional article, punctuation), the one-char
/// spelling tolerance and — importantly — that a wrong answer is graded wrong.
///
/// The spelling tolerance is measured with **standard Levenshtein edit
/// distance** (insert / delete / substitute), so a single-character slip is
/// accepted but a *transposition* is not: swapping two adjacent letters costs
/// two edits (one delete + one insert), i.e. distance 2 > tolerance 1. That is
/// intentional — for IELTS spelling, a letter swap is a genuine misspelling.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ielts_free/core/models/enums/question_type.dart';
import 'package:ielts_free/core/models/reading_option.dart';
import 'package:ielts_free/core/services/grading_service.dart';

void main() {
  const GradingService svc = GradingService();

  GradeResult vocab(VocabQuestionKind kind, String expected, String actual) =>
      svc.gradeVocabulary(kind: kind, expected: expected, actual: actual);

  const List<ReadingOption> mcOptions = <ReadingOption>[
    ReadingOption(questionId: 1, label: 'A', content: 'the bees are healthier'),
    ReadingOption(
        questionId: 1, label: 'B', content: 'the flowering season is longer'),
    ReadingOption(questionId: 1, label: 'C', content: 'honey is more expensive'),
    ReadingOption(
        questionId: 1, label: 'D', content: 'plants have more pesticides'),
  ];

  group('vocabulary — seven kinds', () {
    test('① word → meaning (exact, alternatives split on ／；)', () {
      expect(vocab(VocabQuestionKind.wordToMeaning, '分析', '分析').isCorrect, isTrue);
      final GradeResult r =
          vocab(VocabQuestionKind.wordToMeaning, '减轻；缓和', '缓和');
      expect(r.isCorrect, isTrue);
      expect(r.matchKind, MatchKind.exact);
    });

    test('② meaning → word (case-insensitive)', () {
      expect(
        vocab(VocabQuestionKind.meaningToWord, 'analyze', 'Analyze').isCorrect,
        isTrue,
      );
    });

    test('③ multiple choice (no fuzzy tolerance)', () {
      expect(
        vocab(VocabQuestionKind.multipleChoice, 'reduce', 'reduce').isCorrect,
        isTrue,
      );
      expect(
        vocab(VocabQuestionKind.multipleChoice, 'reduce', 'reducee').isCorrect,
        isFalse,
      );
    });

    test('④ spelling tolerates one character', () {
      // A single-character edit (insert / substitute / delete) is within the
      // edit-distance tolerance of 1 and must be accepted as a fuzzy match.
      final GradeResult insertion =
          vocab(VocabQuestionKind.spelling, 'mitigate', 'mitigatte');
      expect(insertion.isCorrect, isTrue);
      expect(insertion.matchKind, MatchKind.fuzzy);
      expect(insertion.isFuzzy, isTrue);

      final GradeResult substitution =
          vocab(VocabQuestionKind.spelling, 'mitigate', 'mitigete');
      expect(substitution.isCorrect, isTrue);
      expect(substitution.matchKind, MatchKind.fuzzy);
      expect(substitution.isFuzzy, isTrue);

      final GradeResult deletion =
          vocab(VocabQuestionKind.spelling, 'mitigate', 'mitigat');
      expect(deletion.isCorrect, isTrue);
      expect(deletion.matchKind, MatchKind.fuzzy);
      expect(deletion.isFuzzy, isTrue);

      // Boundary / spec: a transposition swaps two adjacent letters and costs
      // two edits (one delete + one insert) → distance 2 > tolerance 1, so it
      // must be rejected. This is intentional: for IELTS spelling, swapping
      // letters is a real misspelling, not a one-character slip.
      final GradeResult transposition =
          vocab(VocabQuestionKind.spelling, 'mitigate', 'mitgitate');
      expect(transposition.isCorrect, isFalse);
      expect(transposition.matchKind, MatchKind.incorrect);
    });

    test('⑤ example cloze accepts article omission', () {
      expect(
        vocab(VocabQuestionKind.exampleCloze, 'the impact', 'impact').isCorrect,
        isTrue,
      );
      expect(
        vocab(VocabQuestionKind.exampleCloze, 'impact', 'the impact').isCorrect,
        isTrue,
      );
    });

    test('⑥ synonym choice (no fuzzy tolerance)', () {
      expect(
        vocab(VocabQuestionKind.synonymChoice, 'alleviate', 'alleviate').isCorrect,
        isTrue,
      );
      expect(
        vocab(VocabQuestionKind.synonymChoice, 'alleviate', 'alleviatee').isCorrect,
        isFalse,
      );
    });

    test('⑦ collocation choice', () {
      expect(
        vocab(VocabQuestionKind.collocationChoice, 'mitigate the impact',
                'mitigate the impact')
            .isCorrect,
        isTrue,
      );
    });
  });

  group('normalisation', () {
    test('case and surrounding whitespace are ignored', () {
      expect(vocab(VocabQuestionKind.spelling, 'analyze', '  ANALYZE  ').isCorrect,
          isTrue);
    });

    test('full-width characters fold to half-width', () {
      expect(
        vocab(VocabQuestionKind.spelling, 'analyze', 'ａｎａｌｙｚｅ').isCorrect,
        isTrue,
      );
    });

    test('internal whitespace is collapsed', () {
      expect(
        vocab(VocabQuestionKind.collocationChoice, 'reduce the impact',
                'reduce   the     impact')
            .isCorrect,
        isTrue,
      );
    });

    test('surrounding punctuation is stripped', () {
      expect(
        vocab(VocabQuestionKind.multipleChoice, 'reduce', 'reduce.').isCorrect,
        isTrue,
      );
    });

    test('a wrong answer is never accepted', () {
      final GradeResult r =
          vocab(VocabQuestionKind.spelling, 'analyze', 'banana');
      expect(r.isCorrect, isFalse);
      expect(r.matchKind, MatchKind.incorrect);
    });

    test('a near miss shorter than 4 letters is not fuzzy-accepted', () {
      expect(vocab(VocabQuestionKind.spelling, 'cat', 'cot').isCorrect, isFalse);
    });

    test('empty user answer is wrong', () {
      expect(vocab(VocabQuestionKind.spelling, 'analyze', '').isCorrect, isFalse);
      expect(vocab(VocabQuestionKind.spelling, 'analyze', '   ').isCorrect, isFalse);
    });
  });

  group('reading — True/False/Not Given', () {
    test('canonical tokens match regardless of case / spacing', () {
      expect(
        svc.gradeTrueFalseNotGiven(correctAnswer: 'FALSE', userAnswer: 'false')
            .isCorrect,
        isTrue,
      );
      expect(
        svc.gradeTrueFalseNotGiven(
                correctAnswer: 'NOT GIVEN', userAnswer: 'notgiven')
            .isCorrect,
        isTrue,
      );
      expect(
        svc.gradeTrueFalseNotGiven(correctAnswer: 'TRUE', userAnswer: 'T')
            .isCorrect,
        isTrue,
      );
      expect(
        svc.gradeTrueFalseNotGiven(correctAnswer: 'FALSE', userAnswer: 'No')
            .isCorrect,
        isTrue,
      );
    });

    test('contradictory answer is wrong', () {
      expect(
        svc.gradeTrueFalseNotGiven(correctAnswer: 'TRUE', userAnswer: 'FALSE')
            .isCorrect,
        isFalse,
      );
    });

    test('empty answer is wrong', () {
      expect(
        svc.gradeTrueFalseNotGiven(correctAnswer: 'TRUE', userAnswer: '').isCorrect,
        isFalse,
      );
    });

    test('gradeReading routes TFNG correctly', () {
      expect(
        svc.gradeReading(
          type: QuestionType.tfng,
          correctAnswer: 'TRUE',
          userAnswer: 'true',
        ).isCorrect,
        isTrue,
      );
    });
  });

  group('reading — multiple choice', () {
    test('label matches label', () {
      expect(
        svc.gradeReading(
          type: QuestionType.multipleChoice,
          correctAnswer: 'B',
          userAnswer: 'B',
          options: mcOptions,
        ).isCorrect,
        isTrue,
      );
    });

    test('option text matches its label', () {
      expect(
        svc.gradeReading(
          type: QuestionType.multipleChoice,
          correctAnswer: 'B',
          userAnswer: 'the flowering season is longer',
          options: mcOptions,
        ).isCorrect,
        isTrue,
      );
    });

    test('a different option is wrong', () {
      expect(
        svc.gradeReading(
          type: QuestionType.multipleChoice,
          correctAnswer: 'B',
          userAnswer: 'A',
          options: mcOptions,
        ).isCorrect,
        isFalse,
      );
    });
  });

  group('reading — completion', () {
    test('exact match', () {
      expect(
        svc.gradeReading(
          type: QuestionType.summaryCompletion,
          correctAnswer: 'declined',
          userAnswer: 'declined',
        ).isCorrect,
        isTrue,
      );
    });

    test('one-character spelling near miss is accepted as fuzzy', () {
      final GradeResult r = svc.gradeReading(
        type: QuestionType.summaryCompletion,
        correctAnswer: 'declined',
        userAnswer: 'decline',
      );
      expect(r.isCorrect, isTrue);
      expect(r.isFuzzy, isTrue);
    });

    test('a wrong completion answer is rejected', () {
      expect(
        svc.gradeReading(
          type: QuestionType.summaryCompletion,
          correctAnswer: 'declined',
          userAnswer: 'increased',
        ).isCorrect,
        isFalse,
      );
    });

    test('optional leading article', () {
      expect(
        svc.gradeReading(
          type: QuestionType.sentenceCompletion,
          correctAnswer: 'the decline',
          userAnswer: 'decline',
        ).isCorrect,
        isTrue,
      );
    });
  });
}
