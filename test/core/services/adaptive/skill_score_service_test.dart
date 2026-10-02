/// Unit tests for [SkillScoreService] — ARCHITECTURE §5.2 / BRIEF §31.
///
/// Each of the four factors is verified in isolation, then the smoothing and
/// clamping, then the no-history fallback and the window behaviour.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ielts_free/core/services/adaptive/adaptive_models.dart';
import 'package:ielts_free/core/services/adaptive/skill_score_service.dart';
import 'package:ielts_free/core/services/clock_service.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 6, 1, 12);

  SkillScoreService service({int window = 20}) =>
      SkillScoreService(clock: FixedClock(now), window: window);

  AnswerSample at(DateTime when, {bool correct = true, int difficulty = 3}) =>
      AnswerSample(
        isCorrect: correct,
        difficulty: difficulty,
        answeredAt: when,
      );

  group('Correctness factor C = Σ(wᵢ·cᵢ)/Σwᵢ', () {
    test('all correct → 1', () {
      final SkillScoreFactors f =
          service().computeFactors(<AnswerSample>[at(now)]);
      expect(f.correctness, 1.0);
    });

    test('all wrong → 0', () {
      final SkillScoreFactors f = service()
          .computeFactors(<AnswerSample>[at(now, correct: false)]);
      expect(f.correctness, 0.0);
    });

    test('recency weighting favours the newer answer (w = 0.9^age)', () {
      // Older correct (w = 0.9) vs newer wrong (w = 1) → 0.9 / 1.9, not 0.5.
      final SkillScoreFactors f = service().computeFactors(<AnswerSample>[
        at(now.subtract(const Duration(days: 1)), correct: true),
        at(now, correct: false),
      ]);
      expect(f.correctness, closeTo(0.9 / 1.9, 1e-9));
    });
  });

  group('DifficultyFactor = 0.7 + 0.3·(D̄−1)/4', () {
    test('easiest (D̄ = 1) → 0.7', () {
      final SkillScoreFactors f =
          service().computeFactors(<AnswerSample>[at(now, difficulty: 1)]);
      expect(f.meanDifficulty, 1.0);
      expect(f.difficultyFactor, closeTo(0.7, 1e-9));
    });

    test('hardest (D̄ = 5) → 1.0', () {
      final SkillScoreFactors f =
          service().computeFactors(<AnswerSample>[at(now, difficulty: 5)]);
      expect(f.meanDifficulty, 5.0);
      expect(f.difficultyFactor, closeTo(1.0, 1e-9));
    });

    test('mid (D̄ = 3) → 0.85', () {
      final SkillScoreFactors f =
          service().computeFactors(<AnswerSample>[at(now, difficulty: 3)]);
      expect(f.difficultyFactor, closeTo(0.85, 1e-9));
    });
  });

  group('ConsistencyFactor = 1 − 0.3·min(1, 2σ)', () {
    test('perfectly stable → 1.0 (σ = 0)', () {
      final SkillScoreFactors f = service().computeFactors(<AnswerSample>[
        at(now, correct: true),
        at(now, correct: true),
      ]);
      expect(f.sigma, closeTo(0.0, 1e-9));
      expect(f.consistencyFactor, closeTo(1.0, 1e-9));
    });

    test('maximally inconsistent (half correct) → 0.7', () {
      final SkillScoreFactors f = service().computeFactors(<AnswerSample>[
        at(now, correct: true),
        at(now, correct: false),
      ]);
      expect(f.sigma, closeTo(0.5, 1e-9));
      expect(f.consistencyFactor, closeTo(0.7, 1e-9));
    });
  });

  group('RecencyFactor = 0.5^(t/14)', () {
    test('just practised → 1.0', () {
      final SkillScoreFactors f =
          service().computeFactors(<AnswerSample>[at(now)]);
      expect(f.recencyFactor, closeTo(1.0, 1e-9));
    });

    test('14 days idle → 0.5', () {
      final SkillScoreFactors f = service().computeFactors(
        <AnswerSample>[at(now.subtract(const Duration(days: 14)))],
      );
      expect(f.recencyFactor, closeTo(0.5, 1e-9));
    });

    test('7 days idle → 0.5^0.5', () {
      final SkillScoreFactors f = service().computeFactors(
        <AnswerSample>[at(now.subtract(const Duration(days: 7)))],
      );
      expect(f.recencyFactor, closeTo(0.7071067811865476, 1e-9));
    });
  });

  group('raw score, smoothing and rounding', () {
    test('raw = 100·C·DF·CF·RF', () {
      // Two correct at difficulty 3, just practised:
      // 100 · 1 · 0.85 · 1 · 1 = 85.
      final SkillScoreFactors f = service().computeFactors(<AnswerSample>[
        at(now, difficulty: 3),
        at(now, difficulty: 3),
      ]);
      expect(f.raw, closeTo(85.0, 1e-9));
    });

    test('score = 0.7·raw + 0.3·previousScore', () {
      final double s = service().score(
        samples: <AnswerSample>[at(now, difficulty: 3), at(now, difficulty: 3)],
        previousScore: 40,
      );
      expect(s, closeTo(71.5, 1e-9));
    });

    test('scoreRounded returns an int', () {
      final int s = service().scoreRounded(
        samples: <AnswerSample>[at(now, difficulty: 3), at(now, difficulty: 3)],
        previousScore: 40,
      );
      expect(s, 72);
    });
  });

  group('boundaries', () {
    test('empty samples → previousScore (Onboarding fallback)', () {
      final SkillScoreService svc = service();
      expect(svc.computeFactors(<AnswerSample>[]).sampleCount, 0);
      expect(svc.computeFactors(<AnswerSample>[]).raw, 0.0);
      expect(svc.score(samples: <AnswerSample>[], previousScore: 55), 55);
    });

    test('score is clamped into [0, 100] on both ends', () {
      final SkillScoreService svc = service();
      expect(
        svc.score(
          samples: <AnswerSample>[at(now, correct: false)],
          previousScore: 1000,
        ),
        100,
      );
      expect(
        svc.score(
          samples: <AnswerSample>[at(now, difficulty: 5)],
          previousScore: -1000,
        ),
        0,
      );
    });

    test('window keeps only the most recent N answers', () {
      final SkillScoreFactors f = service(window: 2).computeFactors(
        <AnswerSample>[
          at(now.subtract(const Duration(days: 3))),
          at(now.subtract(const Duration(days: 2))),
          at(now.subtract(const Duration(days: 1))),
        ],
      );
      expect(f.sampleCount, 2);
    });
  });
}
