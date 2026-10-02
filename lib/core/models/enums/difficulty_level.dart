/// Difficulty scale 1..5 (CEFR A1..C2 mapped to 1..5, see ARCHITECTURE §5).
library;

/// A discrete difficulty level in the inclusive range `1..5`.
enum DifficultyLevel {
  level1(1),
  level2(2),
  level3(3),
  level4(4),
  level5(5);

  const DifficultyLevel(this.value);

  /// The integer stored in the database.
  final int value;

  /// Clamps [value] into `1..5`.
  static int clampValue(int value) {
    if (value < 1) {
      return 1;
    }
    if (value > 5) {
      return 5;
    }
    return value;
  }

  /// Maps an integer to a [DifficultyLevel], clamping out-of-range input.
  static DifficultyLevel fromValue(int? value) =>
      values[clampValue(value ?? 1) - 1];

  /// Maps a nullable integer to a [DifficultyLevel], or `null` when null.
  static DifficultyLevel? maybeFromValue(int? value) =>
      value == null ? null : fromValue(value);
}
