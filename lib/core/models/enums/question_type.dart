/// Reading / question type identifiers.
///
/// Wire values match the `question_type` column in `reading_questions`
/// (docs/ARCHITECTURE-v0.1.md §4.2).
library;

/// The question formats supported by the reading module.
enum QuestionType {
  tfng('TFNG'),
  ynng('YNNG'),
  multipleChoice('MC'),
  matchingHeadings('MATCH_HEADINGS'),
  matchingInformation('MATCH_INFO'),
  sentenceCompletion('SENTENCE_COMPLETION'),
  summaryCompletion('SUMMARY_COMPLETION'),
  tableCompletion('TABLE_COMPLETION'),
  noteCompletion('NOTE_COMPLETION');

  const QuestionType(this.wire);

  /// Value persisted in the database.
  final String wire;

  /// True/False/Not Given style questions (also covers Y/N/NG).
  bool get isTrueFalseNotGiven => this == tfng || this == ynng;

  /// Questions answered by choosing a labelled option (A/B/C/D, headings…).
  bool get isChoice =>
      this == multipleChoice ||
      this == matchingHeadings ||
      this == matchingInformation;

  /// Gap-fill style questions whose answer is a word/phrase from the passage.
  bool get isCompletion =>
      this == sentenceCompletion ||
      this == summaryCompletion ||
      this == tableCompletion ||
      this == noteCompletion;

  /// Parses [value]; falls back to [QuestionType.tfng] for unknown input.
  static QuestionType fromWire(String? value) =>
      maybeFromWire(value) ?? QuestionType.tfng;

  /// Parses [value]; returns `null` when unknown or null.
  static QuestionType? maybeFromWire(String? value) {
    if (value == null) {
      return null;
    }
    for (final QuestionType type in values) {
      if (type.wire == value) {
        return type;
      }
    }
    return null;
  }
}
