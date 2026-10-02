/// Unit tests for [MasteryService] — ARCHITECTURE §5.7 / BRIEF §28.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ielts_free/core/services/adaptive/adaptive_models.dart';
import 'package:ielts_free/core/services/adaptive/mastery_service.dart';

void main() {
  const MasteryService svc = MasteryService();

  group('isMastered threshold (0.80)', () {
    test('just below is not mastered, at/above is', () {
      expect(svc.isMastered(0.79), isFalse);
      expect(svc.isMastered(0.7999), isFalse);
      expect(svc.isMastered(0.80), isTrue);
      expect(svc.isMastered(1.0), isTrue);
    });
  });

  group('wrong answer: mastery − 0.20', () {
    test('drops by 0.20', () {
      final MasteryResult r = svc.evolve(mastery: 0.5, correct: false);
      expect(r.mastery, closeTo(0.30, 1e-9));
      expect(r.isMastered, isFalse);
    });

    test('floors at 0', () {
      final MasteryResult r = svc.evolve(mastery: 0.1, correct: false);
      expect(r.mastery, 0.0);
    });
  });

  group('correct redo: mastery + 0.30', () {
    test('rises by 0.30 and crosses the threshold', () {
      final MasteryResult r = svc.evolve(mastery: 0.5, correct: true);
      expect(r.mastery, closeTo(0.80, 1e-9));
      expect(r.isMastered, isTrue);
      expect(r.justMastered, isTrue);
    });

    test('caps at 1.0', () {
      final MasteryResult r = svc.evolve(mastery: 0.9, correct: true);
      expect(r.mastery, 1.0);
      expect(r.justMastered, isFalse);
    });
  });

  group('mastery transitions', () {
    test('already mastered + correct → no justMastered flag', () {
      final MasteryResult r = svc.evolve(mastery: 0.8, correct: true);
      expect(r.mastery, 1.0);
      expect(r.justMastered, isFalse);
    });

    test('mastered then wrong → re-enters the active queue', () {
      final MasteryResult r = svc.evolve(mastery: 0.9, correct: false);
      expect(r.mastery, closeTo(0.70, 1e-9));
      expect(r.isMastered, isFalse);
      expect(r.reentered, isTrue);
    });

    test('not-mastered + wrong → no reentered flag', () {
      final MasteryResult r = svc.evolve(mastery: 0.5, correct: false);
      expect(r.reentered, isFalse);
    });
  });
}
