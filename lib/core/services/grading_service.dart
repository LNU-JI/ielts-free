/// Answer grading (docs/ARCHITECTURE-v0.1.md §5 grading note, BRIEF §17/§19).
///
/// Covers the seven vocabulary question kinds and every reading question type.
/// All comparisons run on **normalised** text (case, surrounding whitespace,
/// full-width/half-width, collapsed spaces, optional leading article,
/// punctuation) so that trivial formatting differences never cost a mark.
///
/// The service is a pure function (no clock, no IO).
library;

import 'package:ielts_free/core/models/enums/question_type.dart';
import 'package:ielts_free/core/models/reading_option.dart';
import 'package:ielts_free/core/utils/text_utils.dart';

/// The seven vocabulary practice question kinds (BRIEF §17).
enum VocabQuestionKind {
  /// English word → choose / type the Chinese meaning.
  wordToMeaning('WORD_TO_MEANING'),

  /// Chinese meaning → type the English word.
  meaningToWord('MEANING_TO_WORD'),

  /// Four-option multiple choice.
  multipleChoice('MULTIPLE_CHOICE'),

  /// Type the word from memory.
  spelling('SPELLING'),

  /// Fill the gap in an example sentence.
  exampleCloze('EXAMPLE_CLOZE'),

  /// Choose the correct synonym.
  synonymChoice('SYNONYM_CHOICE'),

  /// Choose the correct collocation.
  collocationChoice('COLLOCATION_CHOICE');

  const VocabQuestionKind(this.wire);

  /// Stable identifier.
  final String wire;

  /// Whether a near-miss (edit distance ≤ tolerance) still counts as correct.
  bool get allowsFuzzyMatch {
    switch (this) {
      case VocabQuestionKind.spelling:
      case VocabQuestionKind.meaningToWord:
      case VocabQuestionKind.exampleCloze:
        return true;
      case VocabQuestionKind.wordToMeaning:
      case VocabQuestionKind.multipleChoice:
      case VocabQuestionKind.synonymChoice:
      case VocabQuestionKind.collocationChoice:
        return false;
    }
  }

  /// Whether the answer is a gap-fill whose article may be omitted.
  bool get isCompletion =>
      this == VocabQuestionKind.exampleCloze;
}

/// How an answer matched the expected value.
enum MatchKind {
  /// Matched exactly after normalisation.
  exact,

  /// Matched within the edit-distance tolerance.
  fuzzy,

  /// Did not match.
  incorrect,
}

/// The outcome of grading one answer.
class GradeResult {
  const GradeResult({
    required this.isCorrect,
    required this.matchKind,
    required this.normalizedExpected,
    required this.normalizedActual,
  });

  /// Whether the answer should be scored as correct.
  final bool isCorrect;

  /// Whether the match was exact or fuzzy (only meaningful when correct).
  final MatchKind matchKind;

  /// The normalised expected answer (for feedback / logging).
  final String normalizedExpected;

  /// The normalised user answer (for feedback / logging).
  final String normalizedActual;

  /// Whether the answer was accepted despite a spelling difference.
  bool get isFuzzy => matchKind == MatchKind.fuzzy;

  /// An incorrect result.
  static const GradeResult wrong = GradeResult(
    isCorrect: false,
    matchKind: MatchKind.incorrect,
    normalizedExpected: '',
    normalizedActual: '',
  );
}

/// Grades vocabulary and reading answers.
class GradingService {
  const GradingService({this.defaultFuzzyTolerance = 1});

  /// Default edit-distance tolerance for spelling-style answers.
  final int defaultFuzzyTolerance;

  /// Grades a vocabulary answer.
  ///
  /// [expected] may contain alternatives separated by `/`, `|`, `;` or `；`.
  GradeResult gradeVocabulary({
    required VocabQuestionKind kind,
    required String expected,
    required String actual,
    int? fuzzyTolerance,
    bool allowArticleOmission = true,
  }) {
    final int tolerance = fuzzyTolerance ?? defaultFuzzyTolerance;
    final bool completion = kind.isCompletion && allowArticleOmission;
    final bool fuzzy = kind.allowsFuzzyMatch;

    GradeResult best = GradeResult.wrong;
    for (final String alternative in _alternatives(expected)) {
      final GradeResult candidate = _match(
        expected: alternative,
        actual: actual,
        fuzzy: fuzzy,
        completion: completion,
        tolerance: tolerance,
      );
      if (candidate.matchKind == MatchKind.exact) {
        return candidate;
      }
      if (candidate.matchKind == MatchKind.fuzzy &&
          best.matchKind != MatchKind.fuzzy) {
        best = candidate;
      }
    }
    return best;
  }

  /// Grades a reading answer.
  ///
  /// [options] is required for choice-style questions so that an answer given as
  /// either a label (`B`) or the option text is accepted.
  GradeResult gradeReading({
    required QuestionType type,
    required String correctAnswer,
    required String userAnswer,
    List<ReadingOption> options = const <ReadingOption>[],
    int? fuzzyTolerance,
  }) {
    final int tolerance = fuzzyTolerance ?? defaultFuzzyTolerance;

    if (type.isTrueFalseNotGiven) {
      return gradeTrueFalseNotGiven(
        correctAnswer: correctAnswer,
        userAnswer: userAnswer,
      );
    }

    if (type.isChoice && options.isNotEmpty) {
      return _gradeChoice(
        correctAnswer: correctAnswer,
        userAnswer: userAnswer,
        options: options,
      );
    }

    if (type.isCompletion) {
      return _match(
        expected: correctAnswer,
        actual: userAnswer,
        fuzzy: true,
        completion: true,
        tolerance: tolerance,
      );
    }

    // Fallback: exact / fuzzy text comparison.
    return _match(
      expected: correctAnswer,
      actual: userAnswer,
      fuzzy: true,
      completion: false,
      tolerance: tolerance,
    );
  }

  /// Grades a True/False/Not-Given (or Yes/No/Not-Given) answer.
  GradeResult gradeTrueFalseNotGiven({
    required String correctAnswer,
    required String userAnswer,
  }) {
    final String expected = TextUtils.canonicalTrueFalse(correctAnswer);
    final String actual = TextUtils.canonicalTrueFalse(userAnswer);
    final bool ok = expected == actual && userAnswer.trim().isNotEmpty;
    return GradeResult(
      isCorrect: ok,
      matchKind: ok ? MatchKind.exact : MatchKind.incorrect,
      normalizedExpected: expected,
      normalizedActual: actual,
    );
  }

  // --- internals ----------------------------------------------------------

  GradeResult _gradeChoice({
    required String correctAnswer,
    required String userAnswer,
    required List<ReadingOption> options,
  }) {
    if (userAnswer.trim().isEmpty) {
      return GradeResult.wrong;
    }
    final String expected = _canonicalChoice(correctAnswer, options);
    final String actual = _canonicalChoice(userAnswer, options);
    final bool ok = expected == actual;
    return GradeResult(
      isCorrect: ok,
      matchKind: ok ? MatchKind.exact : MatchKind.incorrect,
      normalizedExpected: expected,
      normalizedActual: actual,
    );
  }

  /// Resolves a label or option text to a stable canonical key.
  String _canonicalChoice(String value, List<ReadingOption> options) {
    final String norm = TextUtils.normalize(value);
    for (final ReadingOption option in options) {
      final String? label = option.label;
      if (label != null && TextUtils.normalize(label) == norm) {
        return 'label:${TextUtils.normalize(label)}';
      }
      if (TextUtils.normalize(option.content) == norm) {
        return 'label:${TextUtils.normalize(label ?? option.content)}';
      }
    }
    return 'text:$norm';
  }

  GradeResult _match({
    required String expected,
    required String actual,
    required bool fuzzy,
    required bool completion,
    required int tolerance,
  }) {
    if (actual.trim().isEmpty) {
      return GradeResult.wrong;
    }

    final String e = completion
        ? TextUtils.normalizeForCompletion(expected)
        : TextUtils.normalize(expected);
    final String a = completion
        ? TextUtils.normalizeForCompletion(actual)
        : TextUtils.normalize(actual);

    if (e.isEmpty) {
      return GradeResult(
        isCorrect: false,
        matchKind: MatchKind.incorrect,
        normalizedExpected: e,
        normalizedActual: a,
      );
    }
    if (e == a) {
      return GradeResult(
        isCorrect: true,
        matchKind: MatchKind.exact,
        normalizedExpected: e,
        normalizedActual: a,
      );
    }
    if (fuzzy && e.length >= 4 && _isLatin(e)) {
      final int distance = TextUtils.levenshtein(e, a);
      if (distance <= tolerance) {
        return GradeResult(
          isCorrect: true,
          matchKind: MatchKind.fuzzy,
          normalizedExpected: e,
          normalizedActual: a,
        );
      }
    }
    return GradeResult(
      isCorrect: false,
      matchKind: MatchKind.incorrect,
      normalizedExpected: e,
      normalizedActual: a,
    );
  }

  /// Splits an expected answer into alternatives (`/`, `|`, `;`, `；`).
  List<String> _alternatives(String expected) {
    final List<String> parts = expected
        .split(RegExp(r'[/|;；]'))
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);
    return parts.isEmpty ? <String>[expected] : parts;
  }

  /// Whether [value] (already normalised) contains only latin letters, spaces,
  /// hyphens and apostrophes — the only case where a spelling near-miss is
  /// meaningful.
  bool _isLatin(String value) => RegExp(r"^[a-z\- ']+$").hasMatch(value);
}
