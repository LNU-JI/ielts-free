/// Mistake taxonomy (docs/BRIEF.md §29).
///
/// V0.1 only produces the Vocabulary and Reading sub-types; the Listening /
/// Writing / Speaking values are defined now so the taxonomy is complete and
/// forward compatible (their labels are used for self-diagnosis only and never
/// claim an official IELTS score — BRIEF §29).
library;

/// A broad category of mistake, used for filtering and prioritisation.
enum ErrorCategory { vocabulary, reading, listening, writing, speaking, unknown }

/// A concrete mistake type, grouped by [category].
enum ErrorType {
  // Vocabulary
  wordMeaning('VOCAB_WORD_MEANING', ErrorCategory.vocabulary),
  synonym('VOCAB_SYNONYM', ErrorCategory.vocabulary),
  collocation('VOCAB_COLLOCATION', ErrorCategory.vocabulary),
  spelling('VOCAB_SPELLING', ErrorCategory.vocabulary),

  // Reading
  readingLocating('READING_LOCATING', ErrorCategory.reading),
  readingParaphrase('READING_PARAPHRASE', ErrorCategory.reading),
  readingMainIdea('READING_MAIN_IDEA', ErrorCategory.reading),
  readingDetail('READING_DETAIL', ErrorCategory.reading),
  readingInference('READING_INFERENCE', ErrorCategory.reading),
  readingLogic('READING_LOGIC', ErrorCategory.reading),
  readingQuestionType('READING_QUESTION_TYPE', ErrorCategory.reading),

  // Listening
  listeningLocating('LISTENING_LOCATING', ErrorCategory.listening),
  listeningSpelling('LISTENING_SPELLING', ErrorCategory.listening),
  listeningNumber('LISTENING_NUMBER', ErrorCategory.listening),
  listeningKeyword('LISTENING_KEYWORD', ErrorCategory.listening),
  listeningParaphrase('LISTENING_PARAPHRASE', ErrorCategory.listening),
  listeningMissedInfo('LISTENING_MISSED_INFO', ErrorCategory.listening),

  // Writing
  writingGrammar('WRITING_GRAMMAR', ErrorCategory.writing),
  writingVocabulary('WRITING_VOCABULARY', ErrorCategory.writing),
  writingCoherence('WRITING_COHERENCE', ErrorCategory.writing),
  writingTaskResponse('WRITING_TASK_RESPONSE', ErrorCategory.writing),
  writingSentenceStructure(
      'WRITING_SENTENCE_STRUCTURE', ErrorCategory.writing),

  // Speaking
  speakingFluency('SPEAKING_FLUENCY', ErrorCategory.speaking),
  speakingVocabulary('SPEAKING_VOCABULARY', ErrorCategory.speaking),
  speakingGrammar('SPEAKING_GRAMMAR', ErrorCategory.speaking),
  speakingPronunciation('SPEAKING_PRONUNCIATION', ErrorCategory.speaking),
  speakingStructure('SPEAKING_STRUCTURE', ErrorCategory.speaking);

  const ErrorType(this.wire, this.category);

  /// Value persisted in the `mistakes.error_type` column.
  final String wire;

  /// The broad category this type belongs to.
  final ErrorCategory category;

  /// Parses [value]; returns `null` when unknown or null.
  static ErrorType? maybeFromWire(String? value) {
    if (value == null) {
      return null;
    }
    for (final ErrorType type in values) {
      if (type.wire == value) {
        return type;
      }
    }
    return null;
  }

  /// Parses [value]; falls back to [ErrorType.wordMeaning] for unknown input.
  static ErrorType fromWire(String? value) =>
      maybeFromWire(value) ?? ErrorType.wordMeaning;
}
