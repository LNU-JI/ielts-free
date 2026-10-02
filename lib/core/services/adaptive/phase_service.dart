/// Exam-countdown phase algorithm (docs/ARCHITECTURE-v0.1.md §5.6, BRIEF §35).
///
/// - `daysRemaining > 90` → `FOUNDATION`
/// - `30 ≤ daysRemaining ≤ 90` → `FOCUS`
/// - `daysRemaining < 30` → `COMPREHENSIVE`
/// - no exam date → `FOUNDATION`
///
/// Boundary values: `90 → FOCUS`, `30 → FOCUS`, `29 → COMPREHENSIVE`.
library;

import 'package:ielts_free/core/models/enums/plan_phase.dart';
import 'package:ielts_free/core/services/clock_service.dart';
import 'package:ielts_free/core/utils/date_utils.dart';

/// Derives the study phase from the exam countdown.
class PhaseService {
  const PhaseService({this.clock = const SystemClock()});

  /// Source of "now"; injected so tests can pin time.
  final Clock clock;

  /// Maps a day count to a phase (`null` → `FOUNDATION`).
  ///
  /// Delegates to [PlanPhase.fromDaysRemaining] so the rule lives in one place.
  PlanPhase phaseOf(int? daysRemaining) =>
      PlanPhase.fromDaysRemaining(daysRemaining);

  /// Maps an exam date (local `YYYY-MM-DD`, or `null`) to a phase.
  ///
  /// `daysRemaining` is the whole-day difference between today (local) and the
  /// exam date, computed with the local calendar convention of §9.6.
  PlanPhase phaseForExamDate(String? examDate) {
    final int? daysRemaining = daysRemainingFor(examDate);
    return phaseOf(daysRemaining);
  }

  /// Whole-day difference from today (local) until [examDate], or `null`.
  int? daysRemainingFor(String? examDate) {
    if (examDate == null || examDate.isEmpty) {
      return null;
    }
    final DateTime today = clock.now();
    return AppDateUtils.daysBetweenLocalDates(
      today,
      AppDateUtils.parseLocalDate(examDate),
    );
  }
}
