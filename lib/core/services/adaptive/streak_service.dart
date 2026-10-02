/// Consecutive-study-days algorithm (docs/ARCHITECTURE-v0.1.md §5.8).
///
/// The unit is the **local calendar date** (`YYYY-MM-DD`):
/// - first ever event → `streak = 1`;
/// - same day again → unchanged (no double counting);
/// - next day → `streak + 1`;
/// - a gap of two or more days → reset to `1`;
/// - a clock rollback (today < last) → unchanged.
///
/// Pure function of an injected [Clock].
library;

import 'package:ielts_free/core/services/adaptive/adaptive_models.dart';
import 'package:ielts_free/core/services/clock_service.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// Maintains the current study streak.
class StreakService {
  const StreakService({this.clock = const SystemClock()});

  /// Source of "now"; injected so tests can pin time.
  final Clock clock;

  /// Folds a study event into the streak state.
  ///
  /// [lastStudyDate] is the stored local `YYYY-MM-DD` (or `null` on first use);
  /// [currentStreak] is the stored streak length.
  StreakResult onStudyEvent({
    required String? lastStudyDate,
    required int currentStreak,
  }) {
    final String today = AppDateUtils.localDateString(clock.now());

    if (lastStudyDate == null || lastStudyDate.isEmpty) {
      return StreakResult(streak: 1, lastStudyDate: today, changed: true);
    }

    final int diff = AppDateUtils.daysBetweenLocalDates(
      AppDateUtils.parseLocalDate(lastStudyDate),
      AppDateUtils.parseLocalDate(today),
    );

    if (diff == 0) {
      // Same day repeated — keep the streak, keep the stored date.
      return StreakResult(
        streak: currentStreak,
        lastStudyDate: lastStudyDate,
        changed: false,
      );
    }
    if (diff == 1) {
      return StreakResult(
        streak: currentStreak + 1,
        lastStudyDate: today,
        changed: true,
      );
    }
    if (diff > 1) {
      // Gap of two or more days — the streak restarts.
      return StreakResult(streak: 1, lastStudyDate: today, changed: true);
    }

    // diff < 0: the clock moved backwards — treat as a no-op.
    return StreakResult(
      streak: currentStreak,
      lastStudyDate: lastStudyDate,
      changed: false,
    );
  }
}
