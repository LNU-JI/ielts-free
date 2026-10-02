/// Vocabulary memory level L0..L6 (docs/BRIEF.md §15, ARCHITECTURE §5.1).
library;

/// The spaced-repetition level of a vocabulary item.
enum MemoryLevel {
  l0(0),
  l1(1),
  l2(2),
  l3(3),
  l4(4),
  l5(5),
  l6(6);

  const MemoryLevel(this.value);

  /// The integer stored in `vocabulary_reviews.memory_level`.
  final int value;

  /// Clamps [value] into `0..6`.
  static int clampValue(int value) {
    if (value < 0) {
      return 0;
    }
    if (value > 6) {
      return 6;
    }
    return value;
  }

  /// Maps an integer to a [MemoryLevel], clamping out-of-range input.
  static MemoryLevel fromValue(int? value) => values[clampValue(value ?? 0)];

  /// Review interval for this level (ARCHITECTURE §5.1).
  Duration get reviewInterval {
    switch (this) {
      case MemoryLevel.l0:
        return const Duration(hours: 4);
      case MemoryLevel.l1:
        return const Duration(days: 1);
      case MemoryLevel.l2:
        return const Duration(days: 3);
      case MemoryLevel.l3:
        return const Duration(days: 7);
      case MemoryLevel.l4:
        return const Duration(days: 14);
      case MemoryLevel.l5:
        return const Duration(days: 30);
      case MemoryLevel.l6:
        return const Duration(days: 60);
    }
  }
}
