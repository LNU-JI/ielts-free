/// Why a listening answer was missed — the five-way taxonomy distilled from
/// established IELTS intensive-listening method.
///
/// Recording the **cause** rather than just "wrong" is what makes the next
/// round different: a missed word is fixed in the word book, a missed *sound*
/// is fixed by shadowing the sentence, and a missed *paraphrase* is fixed by
/// drilling synonym pairs. Wire values match the `error_type` column in
/// `listening_error_log` (lib/core/database/migrations.dart, step 3).
library;

/// The five categories a listening mistake can fall into.
enum ListeningErrorType {
  /// 生词型 — the word was unknown, or known only by its written form.
  vocab('VOCAB', '生词型', '这个词你本来不认识，或只知道拼写、不清楚发音。加入生词本，连同原句一起记。'),

  /// 语音型 — linking, weak forms, elision, stress or accent hid the word.
  phonetic('PHONETIC', '语音型', '连读、弱读、吞音、爆破、重音或口音让你把词听成了别的。收藏这句，模仿原音跟读。'),

  /// 拼写型 — heard correctly, written incorrectly.
  spelling('SPELLING', '拼写型', '答案听到了但拼错：双写、单复数、词尾。做拼写专项。'),

  /// 理解型 — every word heard, sentence structure not parsed.
  comprehension('COMPREHENSION', '理解型', '词都听到了，但没听出句子结构、因果、转折或指代。拆解长难句。'),

  /// 题目对应型 — audio understood, but the paraphrase or distractor missed.
  paraphrase('PARAPHRASE', '题目对应型', '录音听懂了，却没发现它对应题干的同义替换或干扰项。做同义替换专项。');

  const ListeningErrorType(this.wire, this.label, this.hint);

  /// Value persisted in the database.
  final String wire;

  /// Short Chinese label for the UI.
  final String label;

  /// One-line advice on how to fix this class of mistake.
  final String hint;

  /// Parses [value]; falls back to [ListeningErrorType.comprehension].
  static ListeningErrorType fromWire(String? value) =>
      maybeFromWire(value) ?? ListeningErrorType.comprehension;

  /// Parses [value]; returns `null` when unknown or null.
  static ListeningErrorType? maybeFromWire(String? value) {
    if (value == null) {
      return null;
    }
    for (final ListeningErrorType type in values) {
      if (type.wire == value) {
        return type;
      }
    }
    return null;
  }
}
