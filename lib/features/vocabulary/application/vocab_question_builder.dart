/// Builds a vocabulary practice paper from a pool of words.
///
/// The seven question kinds of docs/PRD-v0.1.md §4.4 / BRIEF §16 are produced in
/// rotation, but **every kind degrades gracefully**: when the data a kind needs
/// is missing (no example sentence for a cloze, no synonyms for a synonym
/// question, no collocations for a collocation question), the builder falls back
/// to a kind that always works (`word→meaning` / `meaning→word`) instead of
/// emitting a broken question (FR-030 spirit: missing fields must not error).
///
/// Choice questions draw distractors from the same pool so the wrong options are
/// plausible and never accidentally equal to the answer.
library;

import 'package:flutter/foundation.dart';

import 'package:ielts_free/core/models/vocabulary.dart';
import 'package:ielts_free/core/services/grading_service.dart';

/// One ready-to-render practice question.
@immutable
class VocabPracticeItem {
  const VocabPracticeItem({
    required this.vocabulary,
    required this.kind,
    required this.prompt,
    required this.expected,
    this.options = const <String>[],
    this.clozeSentence,
    this.hint,
  });

  /// The word being practised.
  final Vocabulary vocabulary;

  /// Which of the seven kinds this question is.
  final VocabQuestionKind kind;

  /// The question text shown above the answer area.
  final String prompt;

  /// The canonical correct answer (alternatives may be separated by `；`).
  final String expected;

  /// Selectable options for choice-style kinds (empty for typed kinds).
  final List<String> options;

  /// The sentence with the target word blanked, for [VocabQuestionKind.exampleCloze].
  final String? clozeSentence;

  /// A short hint (phonetic / part of speech), when available.
  final String? hint;

  /// Whether the answer is chosen from [options].
  bool get isChoice => options.isNotEmpty;

  /// The 1-based display number of this kind (`①` … `⑦`).
  int get kindNumber => kind.index + 1;
}

/// Turns words into practice questions.
class VocabQuestionBuilder {
  const VocabQuestionBuilder({this.paperSize = 20, this.distractorCount = 3});

  /// How many questions a paper holds.
  final int paperSize;

  /// How many wrong options a choice question shows (total options = 1 + this).
  final int distractorCount;

  /// Builds a paper of up to [paperSize] questions from [pool].
  ///
  /// The first `min(paperSize, pool.length)` words are used, in order.
  List<VocabPracticeItem> build(List<Vocabulary> pool) {
    if (pool.isEmpty) {
      return const <VocabPracticeItem>[];
    }
    final int count = pool.length < paperSize ? pool.length : paperSize;
    final List<VocabPracticeItem> items = <VocabPracticeItem>[];
    for (int i = 0; i < count; i++) {
      final Vocabulary word = pool[i];
      final VocabQuestionKind kind = _kindFor(i, word, pool);
      items.add(_item(word, kind, pool));
    }
    return List<VocabPracticeItem>.unmodifiable(items);
  }

  /// Rebuilds a single item for [word] with an explicit [kind] (used on restore).
  VocabPracticeItem buildOne(Vocabulary word, VocabQuestionKind kind, List<Vocabulary> pool) =>
      _item(word, _degrade(word, kind, pool), pool);

  // --- kind selection -----------------------------------------------------

  VocabQuestionKind _kindFor(int index, Vocabulary word, List<Vocabulary> pool) {
    final VocabQuestionKind preferred = VocabQuestionKind.values[index % VocabQuestionKind.values.length];
    return _degrade(word, preferred, pool);
  }

  /// Returns [preferred] when its data is available, otherwise a safe fallback.
  VocabQuestionKind _degrade(
    Vocabulary word,
    VocabQuestionKind preferred,
    List<Vocabulary> pool,
  ) {
    switch (preferred) {
      case VocabQuestionKind.exampleCloze:
        return _exampleFor(word) != null ? preferred : VocabQuestionKind.meaningToWord;
      case VocabQuestionKind.synonymChoice:
        return word.synonyms.isNotEmpty && _synonymDistractors(word, pool).isNotEmpty
            ? preferred
            : VocabQuestionKind.wordToMeaning;
      case VocabQuestionKind.collocationChoice:
        return word.collocations.isNotEmpty &&
                _collocationDistractors(word, pool).isNotEmpty
            ? preferred
            : VocabQuestionKind.wordToMeaning;
      case VocabQuestionKind.multipleChoice:
        return _meaningDistractors(word, pool).isNotEmpty
            ? preferred
            : VocabQuestionKind.wordToMeaning;
      case VocabQuestionKind.wordToMeaning:
      case VocabQuestionKind.meaningToWord:
      case VocabQuestionKind.spelling:
        return preferred;
    }
  }

  // --- item construction --------------------------------------------------

  VocabPracticeItem _item(Vocabulary word, VocabQuestionKind kind, List<Vocabulary> pool) {
    final String? hint = _hintFor(word);
    switch (kind) {
      case VocabQuestionKind.wordToMeaning:
        return VocabPracticeItem(
          vocabulary: word,
          kind: kind,
          prompt: word.word,
          expected: word.meaningCn,
          hint: hint,
        );
      case VocabQuestionKind.meaningToWord:
        return VocabPracticeItem(
          vocabulary: word,
          kind: kind,
          prompt: word.meaningCn,
          expected: word.word,
          hint: word.partOfSpeech,
        );
      case VocabQuestionKind.spelling:
        return VocabPracticeItem(
          vocabulary: word,
          kind: kind,
          prompt: word.meaningCn,
          expected: word.word,
          hint: word.phonetic,
        );
      case VocabQuestionKind.exampleCloze:
        final String? sentence = _exampleFor(word);
        if (sentence == null) {
          return _item(word, VocabQuestionKind.meaningToWord, pool);
        }
        return VocabPracticeItem(
          vocabulary: word,
          kind: kind,
          prompt: _cloze(sentence, word.word),
          expected: word.word,
          clozeSentence: sentence,
          hint: word.partOfSpeech,
        );
      case VocabQuestionKind.multipleChoice:
        return VocabPracticeItem(
          vocabulary: word,
          kind: kind,
          prompt: word.word,
          expected: word.meaningCn,
          options: _shuffled(word.meaningCn, _meaningDistractors(word, pool)),
          hint: word.partOfSpeech,
        );
      case VocabQuestionKind.synonymChoice:
        final List<String> distractors = _synonymDistractors(word, pool);
        return VocabPracticeItem(
          vocabulary: word,
          kind: kind,
          prompt: word.word,
          expected: word.synonyms.first,
          options: _shuffled(word.synonyms.first, distractors),
          hint: word.partOfSpeech,
        );
      case VocabQuestionKind.collocationChoice:
        final List<String> distractors = _collocationDistractors(word, pool);
        return VocabPracticeItem(
          vocabulary: word,
          kind: kind,
          prompt: word.word,
          expected: word.collocations.first,
          options: _shuffled(word.collocations.first, distractors),
          hint: word.partOfSpeech,
        );
    }
  }

  String? _hintFor(Vocabulary word) {
    final List<String> parts = <String>[];
    if (word.phonetic != null && word.phonetic!.isNotEmpty) {
      parts.add(word.phonetic!);
    }
    if (word.partOfSpeech != null && word.partOfSpeech!.isNotEmpty) {
      parts.add(word.partOfSpeech!);
    }
    return parts.isEmpty ? null : parts.join('  ');
  }

  /// The first example sentence that actually contains the word (case-insensitive).
  String? _exampleFor(Vocabulary word) {
    final String lower = word.word.toLowerCase();
    for (final VocabularyExample example in word.examples) {
      if (example.en.toLowerCase().contains(lower)) {
        return example.en;
      }
    }
    return null;
  }

  /// Replaces the target word with a blank in [sentence].
  String _cloze(String sentence, String word) {
    final RegExp pattern = RegExp(RegExp.escape(word), caseSensitive: false);
    return sentence.replaceFirst(pattern, '______');
  }

  List<String> _meaningDistractors(Vocabulary word, List<Vocabulary> pool) {
    final List<String> values = <String>[];
    for (final Vocabulary other in pool) {
      if (other.id == word.id) {
        continue;
      }
      final String meaning = other.meaningCn;
      if (meaning.isEmpty || meaning == word.meaningCn) {
        continue;
      }
      if (!values.contains(meaning)) {
        values.add(meaning);
      }
      if (values.length >= distractorCount) {
        break;
      }
    }
    return values;
  }

  List<String> _synonymDistractors(Vocabulary word, List<Vocabulary> pool) {
    final String answer = word.synonyms.isEmpty ? '' : word.synonyms.first;
    final List<String> values = <String>[];
    for (final Vocabulary other in pool) {
      if (other.id == word.id) {
        continue;
      }
      for (final String synonym in other.synonyms) {
        if (synonym == answer || values.contains(synonym)) {
          continue;
        }
        values.add(synonym);
        if (values.length >= distractorCount) {
          return values;
        }
      }
    }
    return values;
  }

  List<String> _collocationDistractors(Vocabulary word, List<Vocabulary> pool) {
    final String answer = word.collocations.isEmpty ? '' : word.collocations.first;
    final List<String> values = <String>[];
    for (final Vocabulary other in pool) {
      if (other.id == word.id) {
        continue;
      }
      for (final String collocation in other.collocations) {
        if (collocation == answer || values.contains(collocation)) {
          continue;
        }
        values.add(collocation);
        if (values.length >= distractorCount) {
          return values;
        }
      }
    }
    return values;
  }

  /// Places [answer] among [distractors] at a deterministic-but-scattered index.
  List<String> _shuffled(String answer, List<String> distractors) {
    final List<String> options = <String>[answer, ...distractors];
    // Deterministic scatter so the correct option is not always first, without
    // pulling in a random source (keeps papers reproducible for tests).
    final int shift = answer.length % options.length;
    if (shift == 0) {
      return List<String>.unmodifiable(options);
    }
    final List<String> rotated = <String>[
      ...options.sublist(options.length - shift),
      ...options.sublist(0, options.length - shift),
    ];
    return List<String>.unmodifiable(rotated);
  }
}
