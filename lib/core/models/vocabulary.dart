/// Vocabulary entry (content database, read-only).
///
/// Maps the `vocabulary` table (docs/ARCHITECTURE-v0.1.md §4.2). Array fields
/// (`synonyms`, `antonyms`, `collocations`, `examples`, `common_mistakes`,
/// `related_words`) are stored as JSON strings and decoded here.
///
/// Topics live in the separate `vocabulary_topics` table and are modelled by
/// [VocabularyTopic]; they are intentionally not duplicated on this row.
library;

import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// A bilingual example sentence.
class VocabularyExample {
  const VocabularyExample({required this.en, this.cn});

  /// English example sentence.
  final String en;

  /// Chinese translation (optional).
  final String? cn;

  /// Builds an example from a JSON object `{ "en": ..., "cn": ... }`.
  factory VocabularyExample.fromMap(Map<String, Object?> map) =>
      VocabularyExample(
        en: asString(map['en']) ?? '',
        cn: asString(map['cn']),
      );

  /// Serialises to a JSON-compatible map.
  Map<String, Object?> toMap() => <String, Object?>{
        'en': en,
        if (cn != null) 'cn': cn,
      };

  @override
  bool operator ==(Object other) =>
      other is VocabularyExample && other.en == en && other.cn == cn;

  @override
  int get hashCode => Object.hash(en, cn);
}

/// A single vocabulary item.
class Vocabulary {
  const Vocabulary({
    this.id,
    required this.word,
    this.phonetic,
    this.partOfSpeech,
    required this.meaningCn,
    this.meaningEn,
    this.difficulty = 3,
    this.cefr,
    this.ieltsLevel,
    this.synonyms = const <String>[],
    this.antonyms = const <String>[],
    this.collocations = const <String>[],
    this.examples = const <VocabularyExample>[],
    this.writingUsage,
    this.speakingUsage,
    this.commonMistakes = const <String>[],
    this.relatedWords = const <String>[],
    this.createdAt,
  });

  /// `vocabulary.id`.
  final int? id;

  /// The head word.
  final String word;

  /// IPA phonetic transcription, e.g. `/ˈænəlaɪz/`.
  final String? phonetic;

  /// Part of speech, e.g. `v.` / `n.` / `adj.`.
  final String? partOfSpeech;

  /// Chinese meaning.
  final String meaningCn;

  /// English definition.
  final String? meaningEn;

  /// Difficulty 1..5.
  final int difficulty;

  /// CEFR level (`A1`..`C2`).
  final String? cefr;

  /// IELTS usage band label, e.g. `High frequency`.
  final String? ieltsLevel;

  /// Synonyms.
  final List<String> synonyms;

  /// Antonyms.
  final List<String> antonyms;

  /// Common collocations.
  final List<String> collocations;

  /// Bilingual example sentences.
  final List<VocabularyExample> examples;

  /// How the word is used in IELTS Writing.
  final String? writingUsage;

  /// How the word is used in IELTS Speaking.
  final String? speakingUsage;

  /// Frequent learner mistakes for this word.
  final List<String> commonMistakes;

  /// Related words (word family).
  final List<String> relatedWords;

  /// Creation timestamp (UTC).
  final DateTime? createdAt;

  /// Builds a [Vocabulary] from a database row / JSON object.
  factory Vocabulary.fromMap(Map<String, Object?> map) => Vocabulary(
        id: asInt(map['id']),
        word: asString(map['word']) ?? '',
        phonetic: asString(map['phonetic']),
        partOfSpeech: asString(map['part_of_speech']),
        meaningCn: asString(map['meaning_cn']) ?? '',
        meaningEn: asString(map['meaning_en']),
        difficulty: intOrDefault(map['difficulty'], 3),
        cefr: asString(map['cefr']),
        ieltsLevel: asString(map['ielts_level']),
        synonyms: decodeStringList(map['synonyms']),
        antonyms: decodeStringList(map['antonyms']),
        collocations: decodeStringList(map['collocations']),
        examples: decodeMapList(map['examples'])
            .map(VocabularyExample.fromMap)
            .toList(growable: false),
        writingUsage: asString(map['writing_usage']),
        speakingUsage: asString(map['speaking_usage']),
        commonMistakes: decodeStringList(map['common_mistakes']),
        relatedWords: decodeStringList(map['related_words']),
        createdAt: AppDateUtils.parseUtcIso(asString(map['created_at'])),
      );

  /// Serialises to a database row map (JSON-encoded array columns).
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'word': word,
        'phonetic': phonetic,
        'part_of_speech': partOfSpeech,
        'meaning_cn': meaningCn,
        'meaning_en': meaningEn,
        'difficulty': difficulty,
        'cefr': cefr,
        'ielts_level': ieltsLevel,
        'synonyms': encodeStringList(synonyms),
        'antonyms': encodeStringList(antonyms),
        'collocations': encodeStringList(collocations),
        'examples':
            encodeMapList(examples.map((VocabularyExample e) => e.toMap()).toList()),
        'writing_usage': writingUsage,
        'speaking_usage': speakingUsage,
        'common_mistakes': encodeStringList(commonMistakes),
        'related_words': encodeStringList(relatedWords),
        'created_at':
            createdAt == null ? null : AppDateUtils.toUtcIso(createdAt!),
      };
}
