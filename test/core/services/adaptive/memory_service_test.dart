/// Unit tests for [MemoryService] — ARCHITECTURE §5.1 / BRIEF §15.
///
/// Covers the L0..L6 interval table, level +1/-1, clamping, streak reset, the
/// "two or more wrong → halve the interval" rule and UTC storage.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ielts_free/core/models/vocabulary_review.dart';
import 'package:ielts_free/core/services/adaptive/memory_service.dart';
import 'package:ielts_free/core/services/clock_service.dart';

void main() {
  final DateTime t0 = DateTime.utc(2026, 1, 1, 8);

  MemoryService service() => MemoryService(clock: FixedClock(t0));

  VocabularyReview review(
    int level, {
    int streak = 0,
    int correct = 0,
    int wrong = 0,
  }) =>
      VocabularyReview(
        vocabularyId: 1,
        memoryLevel: level,
        streak: streak,
        correctCount: correct,
        wrongCount: wrong,
      );

  group('intervalFor — §5.1 spaced-repetition table', () {
    test('L0..L6 match BRIEF §15', () {
      final MemoryService svc = service();
      expect(svc.intervalFor(0), const Duration(hours: 4));
      expect(svc.intervalFor(1), const Duration(days: 1));
      expect(svc.intervalFor(2), const Duration(days: 3));
      expect(svc.intervalFor(3), const Duration(days: 7));
      expect(svc.intervalFor(4), const Duration(days: 14));
      expect(svc.intervalFor(5), const Duration(days: 30));
      expect(svc.intervalFor(6), const Duration(days: 60));
    });

    test('out-of-range levels clamp into 0..6', () {
      final MemoryService svc = service();
      expect(svc.intervalFor(-5), const Duration(hours: 4));
      expect(svc.intervalFor(99), const Duration(days: 60));
    });
  });

  group('applyResult — correct answer', () {
    test('level +1, streak +1, correctCount +1', () {
      final VocabularyReview r =
          service().applyResult(review(0), correct: true);
      expect(r.memoryLevel, 1);
      expect(r.streak, 1);
      expect(r.correctCount, 1);
      expect(r.wrongCount, 0);
    });

    test('nextReviewAt = now + interval(newLevel)', () {
      final VocabularyReview r =
          service().applyResult(review(2), correct: true);
      expect(r.memoryLevel, 3);
      expect(r.nextReviewAt, t0.add(const Duration(days: 7)));
    });

    test('level 6 stays at 6 when correct again', () {
      final VocabularyReview r =
          service().applyResult(review(6), correct: true);
      expect(r.memoryLevel, 6);
      expect(r.nextReviewAt, t0.add(const Duration(days: 60)));
    });

    test('nextReviewAt is stored as UTC', () {
      final VocabularyReview r =
          service().applyResult(review(1), correct: true);
      expect(r.nextReviewAt!.isUtc, isTrue);
      expect(r.lastReviewedAt!.isUtc, isTrue);
    });
  });

  group('applyResult — wrong answer', () {
    test('level -1, streak reset, wrongCount +1', () {
      final VocabularyReview r = service()
          .applyResult(review(3, streak: 5), correct: false);
      expect(r.memoryLevel, 2);
      expect(r.streak, 0);
      expect(r.wrongCount, 1);
      expect(r.correctCount, 0);
    });

    test('level 0 stays at 0 when wrong again', () {
      final VocabularyReview r =
          service().applyResult(review(0), correct: false);
      expect(r.memoryLevel, 0);
      expect(r.nextReviewAt, t0.add(const Duration(hours: 4)));
    });

    test('first wrong keeps the full interval (wrongCount 1)', () {
      final VocabularyReview r = service()
          .applyResult(review(2, wrong: 0), correct: false);
      expect(r.memoryLevel, 1);
      expect(r.wrongCount, 1);
      expect(r.nextReviewAt, t0.add(const Duration(days: 1)));
    });

    test('second consecutive wrong halves the interval (wrongCount >= 2)', () {
      final VocabularyReview r = service()
          .applyResult(review(2, wrong: 1), correct: false);
      expect(r.memoryLevel, 1);
      expect(r.wrongCount, 2);
      // base interval for L1 = 1 day → halved = 12 hours.
      expect(r.nextReviewAt, t0.add(const Duration(hours: 12)));
    });

    test('halving applies at L0 too (4h → 2h)', () {
      final VocabularyReview r = service()
          .applyResult(review(0, wrong: 1), correct: false);
      expect(r.memoryLevel, 0);
      expect(r.wrongCount, 2);
      expect(r.nextReviewAt, t0.add(const Duration(hours: 2)));
    });

    test('a correct answer after two wrong keeps the full interval', () {
      final VocabularyReview r =
          service().applyResult(review(0, wrong: 3), correct: true);
      expect(r.memoryLevel, 1);
      expect(r.nextReviewAt, t0.add(const Duration(days: 1)));
    });
  });

  group('applyResult — out-of-range stored level is clamped', () {
    test('stored level 9 behaves as level 6', () {
      final VocabularyReview r =
          service().applyResult(review(9), correct: true);
      expect(r.memoryLevel, 6);
    });

    test('stored level -3 behaves as level 0', () {
      final VocabularyReview r =
          service().applyResult(review(-3), correct: false);
      expect(r.memoryLevel, 0);
    });
  });
}
