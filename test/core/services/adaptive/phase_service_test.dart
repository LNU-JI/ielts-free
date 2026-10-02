/// Unit tests for [PhaseService] / [PlanPhase] — ARCHITECTURE §5.6 / BRIEF §35.
///
/// Boundary values 91/90/89/31/30/29 and `null` are asserted explicitly.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ielts_free/core/models/enums/plan_phase.dart';
import 'package:ielts_free/core/services/adaptive/phase_service.dart';
import 'package:ielts_free/core/services/clock_service.dart';

void main() {
  const PhaseService svc = PhaseService();

  group('PlanPhase.fromDaysRemaining', () {
    test('> 90 days → FOUNDATION', () {
      expect(PlanPhase.fromDaysRemaining(91), PlanPhase.foundation);
      expect(PlanPhase.fromDaysRemaining(200), PlanPhase.foundation);
    });

    test('30..90 days → FOCUS', () {
      expect(PlanPhase.fromDaysRemaining(90), PlanPhase.focus);
      expect(PlanPhase.fromDaysRemaining(89), PlanPhase.focus);
      expect(PlanPhase.fromDaysRemaining(31), PlanPhase.focus);
      expect(PlanPhase.fromDaysRemaining(30), PlanPhase.focus);
    });

    test('< 30 days → COMPREHENSIVE', () {
      expect(PlanPhase.fromDaysRemaining(29), PlanPhase.comprehensive);
      expect(PlanPhase.fromDaysRemaining(10), PlanPhase.comprehensive);
      expect(PlanPhase.fromDaysRemaining(0), PlanPhase.comprehensive);
    });

    test('null (no exam date) → FOUNDATION', () {
      expect(PlanPhase.fromDaysRemaining(null), PlanPhase.foundation);
      expect(svc.phaseOf(null), PlanPhase.foundation);
    });

    test('negative days still map to COMPREHENSIVE', () {
      expect(PlanPhase.fromDaysRemaining(-5), PlanPhase.comprehensive);
    });
  });

  group('PhaseService.phaseOf mirrors the table', () {
    test('delegates for the boundary set', () {
      expect(svc.phaseOf(91), PlanPhase.foundation);
      expect(svc.phaseOf(90), PlanPhase.focus);
      expect(svc.phaseOf(29), PlanPhase.comprehensive);
    });
  });

  group('PhaseService exam-date derivation', () {
    test('daysRemainingFor computes a whole-day difference', () {
      final PhaseService dated =
          PhaseService(clock: FixedClock(DateTime.utc(2026, 6, 1, 12)));
      expect(dated.daysRemainingFor('2026-06-10'), 9);
      expect(dated.daysRemainingFor('2026-06-01'), 0);
      expect(dated.daysRemainingFor('2026-05-30'), -2);
    });

    test('null / empty exam date → null', () {
      final PhaseService dated =
          PhaseService(clock: FixedClock(DateTime.utc(2026, 6, 1, 12)));
      expect(dated.daysRemainingFor(null), isNull);
      expect(dated.daysRemainingFor(''), isNull);
    });

    test('phaseForExamDate combines both', () {
      final PhaseService dated =
          PhaseService(clock: FixedClock(DateTime.utc(2026, 6, 1, 12)));
      expect(dated.phaseForExamDate('2026-06-10'), PlanPhase.comprehensive);
      expect(dated.phaseForExamDate('2026-08-01'), PlanPhase.focus);
      expect(dated.phaseForExamDate('2027-01-01'), PlanPhase.foundation);
      expect(dated.phaseForExamDate(null), PlanPhase.foundation);
    });
  });
}
