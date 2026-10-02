/// Skill-score algorithm (docs/ARCHITECTURE-v0.1.md §5.2, BRIEF §31).
///
/// `Skill Score = 100 × C × DifficultyFactor × ConsistencyFactor × RecencyFactor`,
/// clamped to `[0, 100]` and smoothed against the previous score. Pure function
/// of an injected [Clock].
library;

import 'dart:math' as math;

import 'package:ielts_free/core/services/adaptive/adaptive_models.dart';
import 'package:ielts_free/core/services/clock_service.dart';

/// The four factors behind a raw skill score, kept for inspection / tests.
class SkillScoreFactors {
  const SkillScoreFactors({
    required this.correctness,
    required this.meanDifficulty,
    required this.difficultyFactor,
    required this.sigma,
    required this.consistencyFactor,
    required this.recencyFactor,
    required this.raw,
    required this.sampleCount,
  });

  /// `C` — recency-weighted accuracy, `[0, 1]`.
  final double correctness;

  /// `D̄` — recency-weighted mean difficulty, `[1, 5]`.
  final double meanDifficulty;

  /// `0.7 + 0.3·(D̄−1)/4`, `[0.7, 1.0]`.
  final double difficultyFactor;

  /// `σ` — recency-weighted standard deviation of correctness.
  final double sigma;

  /// `1 − 0.3·min(1, 2σ)`, `[0.7, 1.0]`.
  final double consistencyFactor;

  /// `0.5^(t/14)`, `(0, 1]`.
  final double recencyFactor;

  /// `100 · C · DifficultyFactor · ConsistencyFactor · RecencyFactor`, `[0, 100]`.
  final double raw;

  /// Number of answers folded in.
  final int sampleCount;

  /// An empty factor set (used when there is no history).
  static const SkillScoreFactors empty = SkillScoreFactors(
    correctness: 0.0,
    meanDifficulty: 1.0,
    difficultyFactor: 0.7,
    sigma: 0.0,
    consistencyFactor: 1.0,
    recencyFactor: 1.0,
    raw: 0.0,
    sampleCount: 0,
  );
}

/// Computes and smooths a skill score.
class SkillScoreService {
  const SkillScoreService({
    this.clock = const SystemClock(),
    this.window = 20,
    this.smoothing = 0.7,
    this.recencyHalfLifeDays = 14,
    this.recencyWeightBase = 0.9,
  });

  /// Source of "now"; injected so tests can pin time.
  final Clock clock;

  /// Maximum number of recent answers considered (`N = 20`).
  final int window;

  /// Weight of the new raw score in the exponential smoothing.
  final double smoothing;

  /// `t` half-life (days) of [SkillScoreFactors.recencyFactor].
  final double recencyHalfLifeDays;

  /// Per-day decay base of the answer weights (`wᵢ = base^ageᵢ`).
  final double recencyWeightBase;

  /// Computes the four factors for [samples] (at most [window], most recent).
  SkillScoreFactors computeFactors(List<AnswerSample> samples) {
    if (samples.isEmpty) {
      return SkillScoreFactors.empty;
    }

    final DateTime now = clock.now();
    final List<AnswerSample> recent = _mostRecent(samples, window);

    double sumW = 0;
    double sumWC = 0;
    double sumWD = 0;
    for (final AnswerSample sample in recent) {
      final double ageDays = _ageDays(now, sample.answeredAt);
      final double w = math.pow(recencyWeightBase, ageDays).toDouble();
      sumW += w;
      sumWC += w * (sample.isCorrect ? 1.0 : 0.0);
      sumWD += w * _clampDifficulty(sample.difficulty);
    }

    if (sumW <= 0) {
      return SkillScoreFactors.empty;
    }

    final double correctness = (sumWC / sumW).clamp(0.0, 1.0).toDouble();
    final double meanDifficulty = (sumWD / sumW).clamp(1.0, 5.0).toDouble();

    double sumWVariance = 0;
    for (final AnswerSample sample in recent) {
      final double ageDays = _ageDays(now, sample.answeredAt);
      final double w = math.pow(recencyWeightBase, ageDays).toDouble();
      final double c = sample.isCorrect ? 1.0 : 0.0;
      final double delta = c - correctness;
      sumWVariance += w * delta * delta;
    }
    final double sigma = math.sqrt(sumWVariance / sumW);

    final double difficultyFactor = 0.7 + 0.3 * (meanDifficulty - 1) / 4;
    final double consistencyFactor = 1 - 0.3 * math.min(1.0, 2 * sigma);

    final double t = _daysSinceMostRecent(now, recent);
    final double recencyFactor = math
        .pow(0.5, t / recencyHalfLifeDays)
        .toDouble()
        .clamp(0.0, 1.0)
        .toDouble();

    final double raw =
        (100 * correctness * difficultyFactor * consistencyFactor * recencyFactor)
            .clamp(0.0, 100.0)
            .toDouble();

    return SkillScoreFactors(
      correctness: correctness,
      meanDifficulty: meanDifficulty,
      difficultyFactor: difficultyFactor,
      sigma: sigma,
      consistencyFactor: consistencyFactor,
      recencyFactor: recencyFactor,
      raw: raw,
      sampleCount: recent.length,
    );
  }

  /// The smoothed score in `[0, 100]`.
  ///
  /// When there is no history the [previousScore] (the Onboarding initial score)
  /// is returned unchanged (§5.2 edge).
  double score({
    required List<AnswerSample> samples,
    required double previousScore,
  }) {
    if (samples.isEmpty) {
      return previousScore.clamp(0.0, 100.0).toDouble();
    }
    final double raw = computeFactors(samples).raw;
    final double blended = smoothing * raw + (1 - smoothing) * previousScore;
    return blended.clamp(0.0, 100.0).toDouble();
  }

  /// The smoothed score rounded to the nearest integer (PRD Q-4: integers only).
  int scoreRounded({
    required List<AnswerSample> samples,
    required double previousScore,
  }) =>
      score(samples: samples, previousScore: previousScore)
          .round()
          .clamp(0, 100)
          .toInt();

  List<AnswerSample> _mostRecent(List<AnswerSample> samples, int limit) {
    if (samples.length <= limit) {
      return List<AnswerSample>.unmodifiable(samples);
    }
    final List<AnswerSample> sorted = List<AnswerSample>.of(samples)
      ..sort((AnswerSample a, AnswerSample b) =>
          a.answeredAt.compareTo(b.answeredAt));
    return sorted.sublist(sorted.length - limit);
  }

  double _daysSinceMostRecent(DateTime now, List<AnswerSample> samples) {
    double minAge = double.infinity;
    for (final AnswerSample sample in samples) {
      final double age = _ageDays(now, sample.answeredAt);
      if (age < minAge) {
        minAge = age;
      }
    }
    return minAge.isFinite ? minAge : 0.0;
  }

  double _ageDays(DateTime now, DateTime answeredAt) {
    final double minutes =
        now.difference(answeredAt.toUtc()).inMinutes.toDouble();
    return math.max(0.0, minutes) / 1440.0;
  }

  double _clampDifficulty(int difficulty) {
    if (difficulty < 1) {
      return 1.0;
    }
    if (difficulty > 5) {
      return 5.0;
    }
    return difficulty.toDouble();
  }
}
