/// Daily task allocation algorithm (docs/ARCHITECTURE-v0.1.md §5.5, BRIEF §34).
///
/// Produces a set of buckets (`vocabulary` / `reading` / `mistakes`) whose
/// minutes sum **exactly** to the daily budget and are each at least 5 minutes.
///
/// V0.1 has no Listening / Writing / Speaking item bank, so those base weights
/// are folded proportionally into the three live buckets (§5.5 note).
///
/// Pure function: no clock, no IO. The caller supplies `daysRemaining` (derived
/// elsewhere with the injected clock).
library;

import 'package:ielts_free/core/models/enums/plan_phase.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/enums/task_type.dart';
import 'package:ielts_free/core/services/adaptive/adaptive_models.dart';
import 'package:ielts_free/core/services/adaptive/phase_service.dart';

/// Builds a day's task plan.
class DailyPlanService {
  const DailyPlanService({
    this.phaseService = const PhaseService(),
    this.minTaskMinutes = 5,
    this.roundTo = 5,
  });

  /// Phase resolver (§5.6).
  final PhaseService phaseService;

  /// Minimum minutes for any emitted task.
  final int minTaskMinutes;

  /// Rounding granularity for the allocation.
  final int roundTo;

  /// Base weights per phase (V0.1 live buckets; the L/W/S shares are folded in).
  static const Map<PlanPhase, Map<DailyPlanBucket, double>> baseWeights =
      <PlanPhase, Map<DailyPlanBucket, double>>{
    PlanPhase.foundation: <DailyPlanBucket, double>{
      DailyPlanBucket.vocabulary: 0.40,
      DailyPlanBucket.reading: 0.25,
      DailyPlanBucket.mistakes: 0.15,
    },
    PlanPhase.focus: <DailyPlanBucket, double>{
      DailyPlanBucket.vocabulary: 0.30,
      DailyPlanBucket.reading: 0.35,
      DailyPlanBucket.mistakes: 0.20,
    },
    PlanPhase.comprehensive: <DailyPlanBucket, double>{
      DailyPlanBucket.vocabulary: 0.20,
      DailyPlanBucket.reading: 0.30,
      DailyPlanBucket.mistakes: 0.35,
    },
  };

  /// Item count for a bucket given its minutes.
  int itemCountFor(DailyPlanBucket bucket, int minutes) {
    switch (bucket) {
      case DailyPlanBucket.vocabulary:
        return (minutes / 0.75).round();
      case DailyPlanBucket.reading:
        final int passages = (minutes / 20).round();
        return passages < 1 ? 1 : passages;
      case DailyPlanBucket.mistakes:
        return (minutes / 2).round();
    }
  }

  /// Builds the plan for [input].
  List<DailyPlanItem> buildPlan(DailyPlanInput input) {
    final int dailyMinutes = input.dailyMinutes;
    if (dailyMinutes <= 0) {
      return const <DailyPlanItem>[];
    }

    final PlanPhase phase = phaseService.phaseOf(input.daysRemaining);
    final Map<DailyPlanBucket, double> base =
        _renormalisedBaseWeights(phase);

    // --- boosts -----------------------------------------------------------
    final double targetScore = _targetScoreForBand(input.targetBand);
    final double mistakesScore = _mistakesCurrentScore(input.skillScores);

    double maxPriority = 0;
    for (final DailyPlanBucket bucket in DailyPlanBucket.values) {
      final double p = _priorityOf(bucket, input);
      if (p > maxPriority) {
        maxPriority = p;
      }
    }

    final DailyPlanBucket? weakestBucket = _weakestBucket(input.weakestSkill);

    final Map<DailyPlanBucket, double> weights = <DailyPlanBucket, double>{};
    final Map<DailyPlanBucket, double> gapBoosts = <DailyPlanBucket, double>{};
    final Map<DailyPlanBucket, double> prioBoosts = <DailyPlanBucket, double>{};
    final Map<DailyPlanBucket, double> weakBoosts = <DailyPlanBucket, double>{};

    for (final DailyPlanBucket bucket in DailyPlanBucket.values) {
      final double currentScore = _currentScoreOf(
        bucket,
        input.skillScores,
        mistakesScore,
      );
      final double gap =
          1 + 0.5 * _positive((targetScore - currentScore) / 100);
      final double priority = _priorityOf(bucket, input);
      final double prio =
          maxPriority > 0 ? 1 + 0.3 * (priority / maxPriority) : 1.0;
      final double weak = bucket == weakestBucket ? 1.2 : 1.0;

      gapBoosts[bucket] = gap;
      prioBoosts[bucket] = prio;
      weakBoosts[bucket] = weak;
      weights[bucket] = base[bucket]! * gap * prio * weak;
    }

    // --- allocation -------------------------------------------------------
    final int targetMinutes =
        dailyMinutes >= minTaskMinutes ? dailyMinutes : minTaskMinutes;
    final int maxBuckets = dailyMinutes >= minTaskMinutes
        ? (dailyMinutes ~/ minTaskMinutes)
        : 1;

    final List<DailyPlanBucket> ordered = DailyPlanBucket.values.toList()
      ..sort((DailyPlanBucket a, DailyPlanBucket b) {
        final int byWeight = weights[b]!.compareTo(weights[a]!);
        return byWeight != 0 ? byWeight : a.index.compareTo(b.index);
      });

    final int keep = _bucketCount(
      maxBuckets: maxBuckets,
      available: ordered.length,
      target: targetMinutes,
    );
    final List<DailyPlanBucket> kept = ordered.sublist(0, keep);

    double keptTotal = 0;
    for (final DailyPlanBucket bucket in kept) {
      keptTotal += weights[bucket]!;
    }
    if (keptTotal <= 0) {
      keptTotal = kept.length.toDouble();
    }

    final Map<DailyPlanBucket, int> minutes = <DailyPlanBucket, int>{};
    for (final DailyPlanBucket bucket in kept) {
      final double raw = weights[bucket]! / keptTotal * targetMinutes;
      final int rounded = _roundTo(raw);
      minutes[bucket] = rounded < minTaskMinutes ? minTaskMinutes : rounded;
    }
    _fixSum(minutes, targetMinutes, weights);

    // --- build items ------------------------------------------------------
    final List<DailyPlanItem> items = <DailyPlanItem>[];
    for (final DailyPlanBucket bucket in kept) {
      final int m = minutes[bucket]!;
      final String reason = _reason(
        phase: phase,
        gap: gapBoosts[bucket]!,
        prio: prioBoosts[bucket]!,
        weak: weakBoosts[bucket]!,
      );
      items.add(
        DailyPlanItem(
          bucket: bucket,
          taskType: _taskTypeOf(bucket),
          skill: _skillOf(bucket),
          minutes: m,
          itemCount: itemCountFor(bucket, m),
          reason: reason,
          priority: _priorityOf(bucket, input),
        ),
      );
    }

    items.sort((DailyPlanItem a, DailyPlanItem b) {
      final int byPriority = b.priority.compareTo(a.priority);
      if (byPriority != 0) {
        return byPriority;
      }
      final int byMinutes = b.minutes.compareTo(a.minutes);
      return byMinutes != 0 ? byMinutes : a.bucket.index.compareTo(b.bucket.index);
    });
    return List<DailyPlanItem>.unmodifiable(items);
  }

  // --- internals ----------------------------------------------------------

  /// Normalises the phase's base weights so the three live buckets sum to 1.
  Map<DailyPlanBucket, double> _renormalisedBaseWeights(PlanPhase phase) {
    final Map<DailyPlanBucket, double> raw =
        baseWeights[phase] ?? baseWeights[PlanPhase.foundation]!;
    double total = 0;
    for (final double value in raw.values) {
      total += value;
    }
    if (total <= 0) {
      total = 1;
    }
    return raw.map(
      (DailyPlanBucket k, double v) =>
          MapEntry<DailyPlanBucket, double>(k, v / total),
    );
  }

  /// Band → 0..100 score. Band 9.0 maps to 100 (PRD Q-4 keeps scores, not bands).
  double _targetScoreForBand(double band) {
    final double clamped = band.clamp(0.0, 9.0).toDouble();
    return clamped / 9.0 * 100.0;
  }

  double _mistakesCurrentScore(Map<SkillType, double> scores) {
    double sum = 0;
    int count = 0;
    for (final SkillType skill in SkillType.fiveDimensions) {
      final double? value = scores[skill];
      if (value != null) {
        sum += value;
        count++;
      }
    }
    return count == 0 ? 0 : sum / count;
  }

  double _currentScoreOf(
    DailyPlanBucket bucket,
    Map<SkillType, double> scores,
    double mistakesScore,
  ) {
    switch (bucket) {
      case DailyPlanBucket.vocabulary:
        return scores[SkillType.vocabulary] ?? 0;
      case DailyPlanBucket.reading:
        return scores[SkillType.reading] ?? 0;
      case DailyPlanBucket.mistakes:
        return mistakesScore;
    }
  }

  double _priorityOf(DailyPlanBucket bucket, DailyPlanInput input) {
    switch (bucket) {
      case DailyPlanBucket.vocabulary:
        return input.priorities[SkillType.vocabulary] ?? 1.0;
      case DailyPlanBucket.reading:
        return input.priorities[SkillType.reading] ?? 1.0;
      case DailyPlanBucket.mistakes:
        final SkillType? weakest = input.weakestSkill;
        if (weakest != null && input.priorities.containsKey(weakest)) {
          return input.priorities[weakest]!;
        }
        double max = 0;
        for (final double value in input.priorities.values) {
          if (value > max) {
            max = value;
          }
        }
        return max > 0 ? max : 1.0;
    }
  }

  DailyPlanBucket? _weakestBucket(SkillType? weakest) {
    if (weakest == null) {
      return null;
    }
    switch (weakest) {
      case SkillType.vocabulary:
        return DailyPlanBucket.vocabulary;
      case SkillType.reading:
        return DailyPlanBucket.reading;
      case SkillType.listening:
      case SkillType.writing:
      case SkillType.speaking:
        return DailyPlanBucket.mistakes;
      default:
        return null;
    }
  }

  TaskType _taskTypeOf(DailyPlanBucket bucket) {
    switch (bucket) {
      case DailyPlanBucket.vocabulary:
        return TaskType.vocabReview;
      case DailyPlanBucket.reading:
        return TaskType.reading;
      case DailyPlanBucket.mistakes:
        return TaskType.mistakeReview;
    }
  }

  SkillType? _skillOf(DailyPlanBucket bucket) {
    switch (bucket) {
      case DailyPlanBucket.vocabulary:
        return SkillType.vocabulary;
      case DailyPlanBucket.reading:
        return SkillType.reading;
      case DailyPlanBucket.mistakes:
        return null;
    }
  }

  int _roundTo(double value) =>
      (value / roundTo).round() * roundTo;

  /// Number of buckets to keep, honouring both the budget cap and the floor.
  ///
  /// A floor-respecting allocation (`every bucket >= minTaskMinutes`, summing to
  /// [target]) can only exist when `buckets * minTaskMinutes <= target`.
  /// `maxBuckets` already guarantees this, but the explicit [floorCap] clamp
  /// documents the precondition `_fixSum` relies on and defends it against a
  /// future change to the cap. Never returns `0`.
  int _bucketCount({
    required int maxBuckets,
    required int available,
    required int target,
  }) {
    int keep = maxBuckets < 1 ? 1 : (maxBuckets > available ? available : maxBuckets);
    if (minTaskMinutes > 0) {
      final int floorCap = target ~/ minTaskMinutes;
      if (floorCap >= 1 && keep > floorCap) {
        keep = floorCap;
      }
    }
    return keep;
  }

  /// Adjusts [minutes] in place so that `Σ minutes == target` while **every**
  /// entry stays `>= minTaskMinutes`.
  ///
  /// Precondition (established by [_bucketCount]): the map is non-empty and
  /// `minutes.length * minTaskMinutes <= target`. Under it, both invariants
  /// always hold:
  ///
  /// 1. **Exact sum** — overshoot is shaved off the largest *reducible* bucket
  ///    until the total reaches [target]; any undershoot is added to the largest
  ///    bucket. Each move stops exactly at [target], never past it.
  /// 2. **Floor** — a reduction is capped at `minutes - minTaskMinutes`, so a
  ///    donor can never drop below the floor; additions only raise values.
  ///
  /// Greedily draining the largest bucket keeps the result as close as possible
  /// to the weight-proportional split. The [roundTo] grid is best-effort: when
  /// [target] is not a multiple of [roundTo] (e.g. 18) "all multiples of
  /// [roundTo]" and "sum exactly [target]" are mathematically incompatible, so
  /// the two invariants above take precedence.
  void _fixSum(
    Map<DailyPlanBucket, int> minutes,
    int target,
    Map<DailyPlanBucket, double> weights,
  ) {
    if (minutes.isEmpty) {
      return;
    }

    // 1. Make the floor explicit (idempotent for the caller's pre-clamped input).
    for (final DailyPlanBucket bucket in minutes.keys) {
      if (minutes[bucket]! < minTaskMinutes) {
        minutes[bucket] = minTaskMinutes;
      }
    }

    int sum = _sumOf(minutes);

    // 2. Shave overshoot off the largest bucket that can still give minutes away.
    while (sum > target) {
      final DailyPlanBucket? donor =
          _largestBucket(minutes, weights, onlyAboveFloor: true);
      if (donor == null) {
        // Unreachable while `length * minTaskMinutes <= target`; guards against
        // an infinite loop should the precondition ever be violated.
        break;
      }
      final int reducible = minutes[donor]! - minTaskMinutes;
      final int excess = sum - target;
      final int take = excess < reducible ? excess : reducible;
      minutes[donor] = minutes[donor]! - take;
      sum -= take;
    }

    // 3. Put any remaining shortfall onto the largest bucket.
    if (sum < target) {
      final DailyPlanBucket recipient = _largestBucket(minutes, weights)!;
      minutes[recipient] = minutes[recipient]! + (target - sum);
    }
  }

  int _sumOf(Map<DailyPlanBucket, int> minutes) {
    int sum = 0;
    for (final int value in minutes.values) {
      sum += value;
    }
    return sum;
  }

  /// The bucket with the most minutes (ties broken by the higher weight). When
  /// [onlyAboveFloor] is set, only buckets that can still be reduced
  /// (`> minTaskMinutes`) are considered, and `null` is returned if none qualify.
  DailyPlanBucket? _largestBucket(
    Map<DailyPlanBucket, int> minutes,
    Map<DailyPlanBucket, double> weights, {
    bool onlyAboveFloor = false,
  }) {
    DailyPlanBucket? best;
    int bestMinutes = -1;
    double bestWeight = double.negativeInfinity;
    for (final DailyPlanBucket bucket in minutes.keys) {
      final int value = minutes[bucket]!;
      if (onlyAboveFloor && value <= minTaskMinutes) {
        continue;
      }
      final double weight = weights[bucket]!;
      if (value > bestMinutes ||
          (value == bestMinutes && weight > bestWeight)) {
        best = bucket;
        bestMinutes = value;
        bestWeight = weight;
      }
    }
    return best;
  }

  String _reason({
    required PlanPhase phase,
    required double gap,
    required double prio,
    required double weak,
  }) {
    final String weakTag = weak > 1.0 ? '（薄弱加成）' : '';
    return '${phase.wire} 阶段：缺口 ×${gap.toStringAsFixed(2)} · '
        '优先级 ×${prio.toStringAsFixed(2)} · 薄弱 ×${weak.toStringAsFixed(2)}$weakTag';
  }

  double _positive(double value) => value > 0 ? value : 0.0;
}
