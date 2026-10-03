/// One spoken sentence of a listening section (content database, read-only).
///
/// Maps the `listening_cues` table (content_pipeline/schema.sql).
///
/// A cue is the unit of **sentence-by-sentence intensive listening** and also
/// the unit of TTS synthesis: the app speaks one cue at a time, so the learner
/// can replay, dictate and shadow a single sentence instead of scrubbing an
/// audio file.
library;

import 'package:ielts_free/core/models/json_utils.dart';

/// A single spoken line inside a listening section.
class ListeningCue {
  const ListeningCue({
    required this.id,
    required this.sectionId,
    required this.orderIndex,
    this.speaker,
    required this.text,
    this.translation,
    this.phoneticNotes = const <String>[],
  });

  /// `listening_cues.id`.
  final int id;

  /// Owning section id.
  final int sectionId;

  /// Order inside the section (1-based).
  final int orderIndex;

  /// Speaker label for multi-voice sections, e.g. `STUDENT` / `TUTOR`.
  final String? speaker;

  /// The spoken sentence — also the text handed to the TTS engine.
  final String text;

  /// Chinese translation, for the review step.
  final String? translation;

  /// Phonetic traps in this sentence, e.g. `连读: check it out`.
  final List<String> phoneticNotes;

  /// Whether this line belongs to a specific speaker.
  bool get hasSpeaker => speaker != null && speaker!.isNotEmpty;

  /// Builds a [ListeningCue] from a database row / JSON object.
  factory ListeningCue.fromMap(Map<String, Object?> map) => ListeningCue(
        id: intOrDefault(map['id'], 0),
        sectionId: intOrDefault(map['section_id'], 0),
        orderIndex: intOrDefault(map['order_index'], 0),
        speaker: asString(map['speaker']),
        text: asString(map['text']) ?? '',
        translation: asString(map['translation']),
        phoneticNotes: decodeStringList(map['phonetic_notes']),
      );

  /// Serialises to a database row map.
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'section_id': sectionId,
        'order_index': orderIndex,
        'speaker': speaker,
        'text': text,
        'translation': translation,
        'phonetic_notes': encodeStringList(phoneticNotes),
      };
}
