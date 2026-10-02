/// Unit tests for [DailyPlanService] — ARCHITECTURE §5.5 / BRIEF §34.
///
/// The two hard invariants are `Σminutes == dailyMinutes` and `every item ≥ 5`
/// minutes. The reachable daily budgets (the app's onboarding / settings presets
/// 30 / 60 / 90 / 120) are asserted directly, and the former P2-1 regression
/// family (non-preset budgets 18 / 19 / 24, see `docs/TEST-REPORT-v0.1.md`) is
/// locked by the "P2-1 regression" group below.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/services/adaptive/adaptive_models.dart';
import 'package:ielts_free/core/services/adaptive/daily_plan_service.dart';

void main() {
  const DailyPlanService svc = DailyPlanService();

  DailyPlanInput input({
    double targetBand = 7.0,
    Map<SkillType, double> scores = const <SkillType, double>{},
    int? daysRemaining = 60,
    int dailyMinutes = 60,
    Map<SkillType, double> priorities = const <SkillType, double>{},
    SkillType? weakestSkill,
  }) =>
      DailyPlanInput(
        targetBand: targetBand,
        skillScores: scores,
        daysRemaining: daysRemaining,
        dailyMinutes: dailyMinutes,
        priorities: priorities,
        weakestSkill: weakestSkill,
      );

  int sumOf(List<DailyPlanItem> items) =>
      items.fold<int>(0, (int acc, DailyPlanItem i) => acc + i.minutes);

  group('Σminutes == dailyMinutes (reachable budgets)', () {
    for (final int dm in <int>[30, 60, 90, 120]) {
      test('dailyMinutes = $dm with several profiles', () {
        final List<DailyPlanInput> inputs = <DailyPlanInput>[
          input(dailyMinutes: dm),
          input(dailyMinutes: dm, daysRemaining: 200),
          input(dailyMinutes: dm, daysRemaining: 10),
          input(
            dailyMinutes: dm,
            scores: <SkillType, double>{
              SkillType.vocabulary: 20,
              SkillType.reading: 80,
            },
            priorities: <SkillType, double>{SkillType.reading: 5.0},
            weakestSkill: SkillType.reading,
          ),
        ];
        for (final DailyPlanInput i in inputs) {
          final List<DailyPlanItem> plan = svc.buildPlan(i);
          expect(sumOf(plan), dm);
          for (final DailyPlanItem item in plan) {
            expect(item.minutes, greaterThanOrEqualTo(5));
          }
        }
      });
    }
  });

  group('P2-1 regression: the 5-minute floor holds for non-preset budgets', () {
    // Exact input family reported by QA (docs/TEST-REPORT-v0.1.md, P2-1). Before
    // the fix, `_fixSum` produced {reading: 3, mistakes: 10, vocabulary: 5} for
    // dailyMinutes = 18, violating the floor.
    DailyPlanInput repro(int dailyMinutes) => input(
          targetBand: 8.0,
          scores: <SkillType, double>{
            SkillType.vocabulary: 90,
            SkillType.reading: 10,
          },
          daysRemaining: 29,
          dailyMinutes: dailyMinutes,
          priorities: <SkillType, double>{SkillType.reading: 5.0},
        );

    test('the reported input keeps every bucket >= 5 and sums to 18', () {
      final List<DailyPlanItem> plan = svc.buildPlan(repro(18));
      expect(sumOf(plan), 18);
      for (final DailyPlanItem item in plan) {
        expect(item.minutes, greaterThanOrEqualTo(5));
      }
      final DailyPlanItem reading = plan
          .firstWhere((DailyPlanItem i) => i.bucket == DailyPlanBucket.reading);
      expect(reading.minutes, greaterThanOrEqualTo(5));
    });

    for (final int dm in <int>[18, 19, 24]) {
      test('dailyMinutes = $dm honours both invariants', () {
        final List<DailyPlanItem> plan = svc.buildPlan(repro(dm));
        expect(sumOf(plan), dm, reason: 'dm=$dm');
        for (final DailyPlanItem item in plan) {
          expect(item.minutes, greaterThanOrEqualTo(5), reason: 'dm=$dm');
        }
      });
    }
  });

  group('allocation follows the phase base weights', () {
    test('FOUNDATION favours vocabulary (30/20/10 at 60 min)', () {
      final List<DailyPlanItem> plan =
          svc.buildPlan(input(dailyMinutes: 60, daysRemaining: 200));
      final Map<DailyPlanBucket, int> byBucket = <DailyPlanBucket, int>{
        for (final DailyPlanItem i in plan) i.bucket: i.minutes,
      };
      expect(byBucket[DailyPlanBucket.vocabulary], 30);
      expect(byBucket[DailyPlanBucket.reading], 20);
      expect(byBucket[DailyPlanBucket.mistakes], 10);
    });

    test('COMPREHENSIVE shifts weight to mistakes', () {
      final List<DailyPlanItem> foundation =
          svc.buildPlan(input(dailyMinutes: 60, daysRemaining: 200));
      final List<DailyPlanItem> comprehensive =
          svc.buildPlan(input(dailyMinutes: 60, daysRemaining: 10));
      int minutesOf(List<DailyPlanItem> items, DailyPlanBucket bucket) => items
          .firstWhere((DailyPlanItem i) => i.bucket == bucket)
          .minutes;
      expect(
        minutesOf(comprehensive, DailyPlanBucket.mistakes),
        greaterThan(minutesOf(foundation, DailyPlanBucket.mistakes)),
      );
      expect(
        minutesOf(comprehensive, DailyPlanBucket.vocabulary),
        lessThan(minutesOf(foundation, DailyPlanBucket.vocabulary)),
      );
    });

    test('null daysRemaining behaves as FOUNDATION', () {
      final List<DailyPlanItem> plan =
          svc.buildPlan(input(dailyMinutes: 60, daysRemaining: null));
      expect(plan, isNotEmpty);
      expect(sumOf(plan), 60);
    });
  });

  group('weakest-skill boost', () {
    test('the weak bucket reason carries the 薄弱 tag', () {
      final List<DailyPlanItem> plan = svc.buildPlan(
        input(dailyMinutes: 60, weakestSkill: SkillType.vocabulary),
      );
      final DailyPlanItem vocab = plan
          .firstWhere((DailyPlanItem i) => i.bucket == DailyPlanBucket.vocabulary);
      expect(vocab.reason, contains('薄弱'));
    });

    test('a listening/writing/speaking weakness maps onto the mistakes bucket',
        () {
      final List<DailyPlanItem> plan = svc.buildPlan(
        input(dailyMinutes: 60, weakestSkill: SkillType.listening),
      );
      final DailyPlanItem mistakes = plan
          .firstWhere((DailyPlanItem i) => i.bucket == DailyPlanBucket.mistakes);
      expect(mistakes.reason, contains('薄弱'));
    });
  });

  group('itemCountFor', () {
    test('vocabulary: round(minutes / 0.75)', () {
      expect(svc.itemCountFor(DailyPlanBucket.vocabulary, 15), 20);
      expect(svc.itemCountFor(DailyPlanBucket.vocabulary, 5), 7);
    });

    test('reading: max(1, round(minutes / 20))', () {
      expect(svc.itemCountFor(DailyPlanBucket.reading, 20), 1);
      expect(svc.itemCountFor(DailyPlanBucket.reading, 30), 2);
      expect(svc.itemCountFor(DailyPlanBucket.reading, 5), 1);
    });

    test('mistakes: round(minutes / 2)', () {
      expect(svc.itemCountFor(DailyPlanBucket.mistakes, 10), 5);
      expect(svc.itemCountFor(DailyPlanBucket.mistakes, 5), 3);
      expect(svc.itemCountFor(DailyPlanBucket.mistakes, 15), 8);
    });
  });

  group('degenerate budgets', () {
    test('dailyMinutes <= 0 → empty plan', () {
      expect(svc.buildPlan(input(dailyMinutes: 0)), isEmpty);
      expect(svc.buildPlan(input(dailyMinutes: -10)), isEmpty);
    });

    test('tiny budgets still yield at least one 5-minute task', () {
      for (final int dm in <int>[1, 5, 10, 14]) {
        final List<DailyPlanItem> plan = svc.buildPlan(input(dailyMinutes: dm));
        expect(plan, isNotEmpty, reason: 'dm=$dm');
        for (final DailyPlanItem item in plan) {
          expect(item.minutes, greaterThanOrEqualTo(5), reason: 'dm=$dm');
        }
        expect(sumOf(plan), dm < 5 ? 5 : dm, reason: 'dm=$dm');
      }
    });
  });

  group('every task is a multiple of 5 minutes in the normal range', () {
    test('30 / 60 / 90 / 120 produce 5-minute-aligned allocations', () {
      for (final int dm in <int>[30, 60, 90, 120]) {
        final List<DailyPlanItem> plan = svc.buildPlan(input(dailyMinutes: dm));
        for (final DailyPlanItem item in plan) {
          expect(item.minutes % 5, 0, reason: 'dm=$dm');
        }
      }
    });
  });
}
