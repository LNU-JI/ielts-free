/// Listening question format identifiers.
///
/// Wire values match the `question_type` column in `listening_questions`
/// (content_pipeline/schema.sql).
library;

/// The question formats supported by the listening module.
enum ListeningQuestionType {
  formCompletion('FORM_COMPLETION'),
  sentenceCompletion('SENTENCE_COMPLETION'),
  multipleChoice('MC'),
  matching('MATCHING'),
  mapLabelling('MAP');

  const ListeningQuestionType(this.wire);

  /// Value persisted in the database.
  final String wire;

  /// Questions answered by choosing a labelled option.
  bool get isChoice =>
      this == multipleChoice || this == matching || this == mapLabelling;

  /// Gap-fill questions whose answer is a word or phrase from the audio.
  bool get isCompletion =>
      this == formCompletion || this == sentenceCompletion;

  /// Chinese label for the UI.
  String get label => switch (this) {
        ListeningQuestionType.formCompletion => '表格填空',
        ListeningQuestionType.sentenceCompletion => '句子填空',
        ListeningQuestionType.multipleChoice => '单项选择',
        ListeningQuestionType.matching => '配对题',
        ListeningQuestionType.mapLabelling => '地图标注',
      };

  /// Parses [value]; falls back to [ListeningQuestionType.formCompletion].
  static ListeningQuestionType fromWire(String? value) =>
      maybeFromWire(value) ?? ListeningQuestionType.formCompletion;

  /// Parses [value]; returns `null` when unknown or null.
  static ListeningQuestionType? maybeFromWire(String? value) {
    if (value == null) {
      return null;
    }
    for (final ListeningQuestionType type in values) {
      if (type.wire == value) {
        return type;
      }
    }
    return null;
  }
}
