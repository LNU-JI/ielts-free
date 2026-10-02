/// Unit tests for [PriorityService] — ARCHITECTURE §5.3 / BRIEF §32.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ielts_free/core/services/adaptive/adaptive_models.dart';
import 'package:ielts_free/core/services/adaptive/priority_service.dart';

void main() {
  const PriorityService svc = PriorityService();

  group('ErrorFrequency = min(5, 1 + log2(1 + E))', () {
    test('quantised values', () {
      expect(svc.errorFrequency(0), closeTo(1.0, 1e-9));
      expect(svc.errorFrequency(1), closeTo(2.0, 1e-9));
      expect(svc.errorFrequency(3), closeTo(3.0, 1e-9));
      expect(svc.errorFrequency(7), closeTo(4.0, 1e-9));
      expect(svc.errorFrequency(15), closeTo(5.0, 1e-9));
    });

    test('clamped at 5 and floors at 1', () {
      expect(svc.errorFrequency(31), closeTo(5.0, 1e-9));
      expect(svc.errorFrequency(1000), closeTo(5.0, 1e-9));
      expect(svc.errorFrequency(-4), closeTo(1.0, 1e-9));
    });

    test('edge: no errors → neutral 1', () {
      expect(svc.errorFrequency(0), 1.0);
    });
  });

  group('SkillImportance = clamp(1 + (target−current)/100, 1, 2)', () {
    test('behind target → >1', () {
      expect(
        svc.skillImportance(targetScore: 80, currentScore: 40),
        closeTo(1.4, 1e-9),
      );
      expect(
        svc.skillImportance(targetScore: 100, currentScore: 0),
        closeTo(2.0, 1e-9),
      );
    });

    test('edge: currentScore > target → collapses to 1', () {
      expect(
        svc.skillImportance(targetScore: 40, currentScore: 80),
        1.0,
      );
    });
  });

  group('Recency = 0.5^(daysSinceLastError / 7)', () {
    test('quantised values', () {
      expect(svc.recency(0), closeTo(1.0, 1e-9));
      expect(svc.recency(7), closeTo(0.5, 1e-9));
      expect(svc.recency(14), closeTo(0.25, 1e-9));
      expect(svc.recency(3), closeTo(0.7429971447, 1e-9));
    });

    test('edge: no practice → Recency 1', () {
      expect(svc.recency(0), 1.0);
    });

    test('negative days clamp to 1', () {
      expect(svc.recency(-3), closeTo(1.0, 1e-9));
    });
  });

  group('Difficulty = 1 + 0.2·(D̄−1)', () {
    test('quantised and clamped', () {
      expect(svc.difficultyFactor(1), closeTo(1.0, 1e-9));
      expect(svc.difficultyFactor(3), closeTo(1.4, 1e-9));
      expect(svc.difficultyFactor(5), closeTo(1.8, 1e-9));
      expect(svc.difficultyFactor(0), closeTo(1.0, 1e-9));
      expect(svc.difficultyFactor(10), closeTo(1.8, 1e-9));
    });
  });

  group('evaluate / rank', () {
    PriorityCandidate candidate(
      String key, {
      int errors = 0,
      double target = 80,
      double current = 40,
      double days = 0,
      double difficulty = 3,
    }) =>
        PriorityCandidate(
          key: key,
          errorCount: errors,
          targetScore: target,
          currentScore: current,
          daysSinceLastError: days,
          averageDifficulty: difficulty,
        );

    test('priority = EF × SI × Recency × Difficulty', () {
      final PriorityItem item = svc.evaluate(candidate('VOCABULARY', errors: 3));
      // 3 × 1.4 × 1 × 1.4 = 5.88
      expect(item.priority, closeTo(5.88, 1e-9));
      expect(item.errorFrequency, closeTo(3.0, 1e-9));
      expect(item.skillImportance, closeTo(1.4, 1e-9));
      expect(item.recency, closeTo(1.0, 1e-9));
      expect(item.difficulty, closeTo(1.4, 1e-9));
    });

    test('rank returns descending order', () {
      final List<PriorityItem> ranked = svc.rank(<PriorityCandidate>[
        candidate('low', errors: 0),
        candidate('high', errors: 15),
        candidate('mid', errors: 3),
      ]);
      expect(ranked.map((PriorityItem i) => i.key).toList(),
          <String>['high', 'mid', 'low']);
    });

    test('ties break deterministically by key', () {
      final List<PriorityItem> ranked = svc.rank(<PriorityCandidate>[
        candidate('b', errors: 3),
        candidate('a', errors: 3),
      ]);
      expect(ranked.map((PriorityItem i) => i.key).toList(),
          <String>['a', 'b']);
    });

    test('maxPriority is 0 for an empty list', () {
      expect(svc.maxPriority(<PriorityItem>[]), 0);
    });

    test('a repeatedly-wrong skill outranks a fresh one', () {
      final List<PriorityItem> ranked = svc.rank(<PriorityCandidate>[
        candidate('stale', errors: 5, days: 14),
        candidate('recent', errors: 5, days: 0),
      ]);
      expect(ranked.first.key, 'recent');
    });
  });
}
