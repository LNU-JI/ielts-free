/// Unit tests for [DifficultyService] — ARCHITECTURE §5.4 / BRIEF §33.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ielts_free/core/services/adaptive/adaptive_models.dart';
import 'package:ielts_free/core/services/adaptive/difficulty_service.dart';

void main() {
  final DateTime t0 = DateTime.utc(2026, 6, 1, 12);
  const DifficultyService svc = DifficultyService();

  AnswerSample a(bool correct) =>
      AnswerSample(isCorrect: correct, difficulty: 3, answeredAt: t0);

  List<AnswerSample> window(List<bool> pattern) =>
      pattern.map(a).toList(growable: false);

  group('window shorter than 3 never fires R1/R2', () {
    test('two correct answers → unchanged', () {
      final DifficultyDecision d =
          svc.evaluate(window: window(<bool>[true, true]), currentDifficulty: 3);
      expect(d.action, DifficultyAction.unchanged);
      expect(d.newDifficulty, 3);
    });

    test('two wrong answers → unchanged (no focus yet)', () {
      final DifficultyDecision d = svc.evaluate(
        window: window(<bool>[false, false]),
        currentDifficulty: 3,
      );
      expect(d.action, DifficultyAction.unchanged);
      expect(d.focusMode, isFalse);
    });
  });

  group('R1 upgrade (accuracy > 85%)', () {
    test('three correct → difficulty + 1', () {
      final DifficultyDecision d = svc.evaluate(
        window: window(<bool>[true, true, true]),
        currentDifficulty: 3,
      );
      expect(d.action, DifficultyAction.upgrade);
      expect(d.newDifficulty, 4);
    });

    test('caps at 5', () {
      final DifficultyDecision d = svc.evaluate(
        window: window(<bool>[true, true, true]),
        currentDifficulty: 5,
      );
      expect(d.action, DifficultyAction.upgrade);
      expect(d.newDifficulty, 5);
    });

    test('0.85 is NOT above the threshold (17/20 → unchanged)', () {
      final DifficultyDecision d = svc.evaluate(
        window: window(List<bool>.generate(20, (int i) => i >= 3)),
        currentDifficulty: 3,
      );
      expect(d.action, DifficultyAction.unchanged);
    });

    test('0.90 IS above the threshold (18/20 → upgrade)', () {
      final DifficultyDecision d = svc.evaluate(
        window: window(List<bool>.generate(20, (int i) => i >= 2)),
        currentDifficulty: 3,
      );
      expect(d.action, DifficultyAction.upgrade);
    });
  });

  group('R2 downgrade (accuracy < 60%)', () {
    test('40% accuracy → difficulty − 1', () {
      final DifficultyDecision d = svc.evaluate(
        window: window(<bool>[false, true, false, false, true]),
        currentDifficulty: 3,
      );
      expect(d.action, DifficultyAction.downgrade);
      expect(d.newDifficulty, 2);
    });

    test('floors at 1', () {
      final DifficultyDecision d = svc.evaluate(
        window: window(<bool>[false, true, false, false, true]),
        currentDifficulty: 1,
      );
      expect(d.action, DifficultyAction.downgrade);
      expect(d.newDifficulty, 1);
    });

    test('exactly 60% does not downgrade', () {
      final DifficultyDecision d = svc.evaluate(
        window: window(<bool>[true, true, true, false, false]),
        currentDifficulty: 3,
      );
      expect(d.action, DifficultyAction.unchanged);
    });
  });

  group('R3 focused practice (three consecutive wrong)', () {
    test('three trailing wrong → focus', () {
      final DifficultyDecision d = svc.evaluate(
        window: window(<bool>[false, false, false]),
        currentDifficulty: 3,
      );
      expect(d.action, DifficultyAction.focus);
      expect(d.focusMode, isTrue);
      expect(d.newDifficulty, 3);
    });

    test('R3 takes precedence over R2 (0% would downgrade)', () {
      final DifficultyDecision d = svc.evaluate(
        window: window(<bool>[false, false, false]),
        currentDifficulty: 3,
      );
      expect(d.action, DifficultyAction.focus);
      expect(d.action, isNot(DifficultyAction.downgrade));
    });

    test('only two trailing wrong is not enough', () {
      final DifficultyDecision d = svc.evaluate(
        window: window(<bool>[true, false, false]),
        currentDifficulty: 3,
      );
      expect(d.action, isNot(DifficultyAction.focus));
      expect(d.action, DifficultyAction.downgrade);
    });

    test('three trailing wrong inside a longer window → focus', () {
      final DifficultyDecision d = svc.evaluate(
        window: window(<bool>[true, true, true, false, false, false]),
        currentDifficulty: 3,
      );
      expect(d.action, DifficultyAction.focus);
    });
  });

  group('trailingConsecutiveWrong', () {
    test('counts the wrong run at the end', () {
      expect(svc.trailingConsecutiveWrong(window(<bool>[true, false, false, false])), 3);
      expect(svc.trailingConsecutiveWrong(window(<bool>[false, false, true])), 0);
      expect(svc.trailingConsecutiveWrong(window(<bool>[true, true, false, false])), 2);
      expect(svc.trailingConsecutiveWrong(<AnswerSample>[]), 0);
    });
  });
}
