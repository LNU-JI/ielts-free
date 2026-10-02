/// Skill dimension identifiers used across answers, mistakes and scores.
///
/// The wire values match the `skill` column in `skill_scores`, `user_answers`
/// and `mistakes` (docs/ARCHITECTURE-v0.1.md §4.3).
library;

/// A skill, either one of the five headline dimensions or a reading sub-skill.
enum SkillType {
  vocabulary('VOCABULARY'),
  reading('READING'),
  listening('LISTENING'),
  writing('WRITING'),
  speaking('SPEAKING'),
  readingTfng('READING_TFNG'),
  readingMc('READING_MC'),
  readingSummary('READING_SUMMARY'),
  readingDetail('DETAIL'),
  readingInference('INFERENCE'),
  readingMatchHeadings('MATCH_HEADINGS');

  const SkillType(this.wire);

  /// Value persisted in the database.
  final String wire;

  /// The five headline dimensions shown on the Dashboard.
  static const List<SkillType> fiveDimensions = <SkillType>[
    vocabulary,
    reading,
    listening,
    writing,
    speaking,
  ];

  /// The reading sub-dimensions (BRIEF §30).
  static const List<SkillType> readingSubSkills = <SkillType>[
    readingTfng,
    readingMc,
    readingSummary,
    readingDetail,
    readingInference,
    readingMatchHeadings,
  ];

  /// Whether this is a reading sub-skill rather than a headline dimension.
  bool get isReadingSubSkill => readingSubSkills.contains(this);

  /// Parses [value]; falls back to [SkillType.vocabulary] for unknown input.
  static SkillType fromWire(String? value) =>
      maybeFromWire(value) ?? SkillType.vocabulary;

  /// Parses [value]; returns `null` when unknown or null.
  static SkillType? maybeFromWire(String? value) {
    if (value == null) {
      return null;
    }
    for (final SkillType skill in values) {
      if (skill.wire == value) {
        return skill;
      }
    }
    return null;
  }
}
