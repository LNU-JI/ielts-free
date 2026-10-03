/// The three parts of the IELTS Speaking test.
///
/// Wire values match the `part` column in `speaking_topics`
/// (content_pipeline/schema.sql). The timing defaults mirror the real test:
/// Part 2 gives one minute to prepare and up to two minutes to speak.
library;

/// Speaking test part.
enum SpeakingPart {
  /// Part 1 — short questions about familiar topics.
  part1(1, 'Part 1', '日常话题快问快答', 0, 30),

  /// Part 2 — a cue card with one minute of preparation.
  part2(2, 'Part 2', '个人陈述（提纲卡）', 60, 120),

  /// Part 3 — a deeper discussion linked to the Part 2 topic.
  part3(3, 'Part 3', '深入讨论与观点表达', 0, 45);

  const SpeakingPart(
    this.wire,
    this.label,
    this.description,
    this.prepSeconds,
    this.speakSeconds,
  );

  /// Value persisted in the database.
  final int wire;

  /// Short label for the UI.
  final String label;

  /// One-line Chinese description of what this part tests.
  final String description;

  /// Preparation time in seconds (0 when the part has none).
  final int prepSeconds;

  /// Suggested speaking time in seconds.
  final int speakSeconds;

  /// Whether this part uses a cue card.
  bool get hasCueCard => this == SpeakingPart.part2;

  /// Parses [value]; falls back to [SpeakingPart.part1].
  static SpeakingPart fromWire(int? value) =>
      maybeFromWire(value) ?? SpeakingPart.part1;

  /// Parses [value]; returns `null` when unknown or null.
  static SpeakingPart? maybeFromWire(int? value) {
    if (value == null) {
      return null;
    }
    for (final SpeakingPart part in values) {
      if (part.wire == value) {
        return part;
      }
    }
    return null;
  }
}
