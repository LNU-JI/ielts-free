/// Text normalisation and answer comparison.
///
/// Shared by the grading service (T03) and by content validation so that the
/// same notion of "the answer matches" is used everywhere.
library;

/// Pure string helpers (no IO).
abstract final class TextUtils {
  const TextUtils._();

  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _surroundingPunctuation = RegExp(r'''^[\s.,;:!?"'`()\[\]{}]+|[\s.,;:!?"'`()\[\]{}]+$''');
  static final RegExp _innerPunctuation = RegExp(r'''[.,;:!?"'`]''');

  /// Leading English articles that are optional in gap-fill answers.
  static const Set<String> _articles = <String>{'a', 'an', 'the'};

  /// Converts full-width ASCII (and the ideographic space) to half-width.
  ///
  /// Users on Chinese IMEs frequently type full-width characters
  /// (`Ａ`, `１`, `，` …); folding them to half-width makes comparison robust
  /// (ARCHITECTURE §5 grading note: 全角/半角 must be normalised).
  static String toHalfWidth(String input) {
    final StringBuffer buffer = StringBuffer();
    for (final int code in input.runes) {
      if (code == 0x3000) {
        // Ideographic space → normal space.
        buffer.write(' ');
      } else if (code >= 0xFF01 && code <= 0xFF5E) {
        buffer.writeCharCode(code - 0xFEE0);
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  /// Normalises free-text answers for comparison.
  ///
  /// Folds full-width to half-width, lower-cases, trims, collapses internal
  /// whitespace and strips surrounding punctuation. Used for vocabulary typing /
  /// completion answers.
  static String normalize(String input) {
    String value = toHalfWidth(input).trim().toLowerCase();
    value = value.replaceAll(_whitespace, ' ');
    value = value.replaceAll(_surroundingPunctuation, '');
    return value;
  }

  /// A stricter normalisation that also removes inner punctuation and articles.
  ///
  /// Useful for sentence-completion answers where punctuation is not marked.
  static String normalizeLoose(String input) {
    String value = normalize(input);
    value = value.replaceAll(_innerPunctuation, '');
    value = value.replaceAll(_whitespace, '');
    return value;
  }

  /// Whether two answers are equivalent under [normalize].
  static bool answersMatch(String expected, String actual) =>
      normalize(expected) == normalize(actual);

  /// Whether two answers are equivalent under [normalizeLoose].
  static bool answersMatchLoose(String expected, String actual) =>
      normalizeLoose(expected) == normalizeLoose(actual);

  /// Removes a leading English article (`a` / `an` / `the`) if present.
  ///
  /// Gap-fill answers often accept the noun with or without its article
  /// (ARCHITECTURE §5 grading note: 可选冠词).
  static String stripLeadingArticle(String input) {
    final List<String> parts = normalize(input).split(' ');
    if (parts.isNotEmpty && _articles.contains(parts.first)) {
      parts.removeAt(0);
    }
    return parts.join(' ');
  }

  /// Normalisation used for gap-fill / completion answers.
  ///
  /// Applies [stripLeadingArticle] first (so `the cat` and `cat` match), then
  /// [normalizeLoose] to drop inner punctuation and residual whitespace.
  static String normalizeForCompletion(String input) =>
      normalizeLoose(stripLeadingArticle(input));

  /// Canonicalises a True / False / Not Given style answer.
  ///
  /// Accepts `T`/`TRUE`/`YES` → `TRUE`, `F`/`FALSE`/`NO` → `FALSE`,
  /// `NG`/`NOT GIVEN`/`NOTGIVEN` → `NOT GIVEN`. Returns the normalised input
  /// upper-cased when it does not match a known token.
  static String canonicalTrueFalse(String input) {
    final String value = normalize(input).toUpperCase().replaceAll(' ', '');
    switch (value) {
      case 'T':
      case 'TRUE':
      case 'YES':
      case 'Y':
        return 'TRUE';
      case 'F':
      case 'FALSE':
      case 'NO':
      case 'N':
        return 'FALSE';
      case 'NG':
      case 'NOTGIVEN':
      case 'NOT-GIVEN':
        return 'NOT GIVEN';
      default:
        return normalize(input).toUpperCase();
    }
  }

  /// Levenshtein edit distance between [a] and [b].
  static int levenshtein(String a, String b) {
    if (a == b) {
      return 0;
    }
    if (a.isEmpty) {
      return b.length;
    }
    if (b.isEmpty) {
      return a.length;
    }

    List<int> previous = List<int>.generate(b.length + 1, (int i) => i);
    List<int> current = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      current[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final int cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        final int deletion = previous[j + 1] + 1;
        final int insertion = current[j] + 1;
        final int substitution = previous[j] + cost;
        current[j + 1] = _min3(deletion, insertion, substitution);
      }
      final List<int> swap = previous;
      previous = current;
      current = swap;
    }
    return previous[b.length];
  }

  /// Similarity of [a] and [b] in `[0, 1]` (1 = identical after normalisation).
  static double similarity(String a, String b) {
    final String x = normalize(a);
    final String y = normalize(b);
    if (x.isEmpty && y.isEmpty) {
      return 1;
    }
    final int maxLen = x.length > y.length ? x.length : y.length;
    if (maxLen == 0) {
      return 1;
    }
    final int distance = levenshtein(x, y);
    return 1 - (distance / maxLen);
  }

  /// Collapses all whitespace runs in [input] to a single space and trims.
  static String collapseWhitespace(String input) =>
      input.trim().replaceAll(_whitespace, ' ');

  static int _min3(int a, int b, int c) {
    int result = a < b ? a : b;
    if (c < result) {
      result = c;
    }
    return result;
  }
}
