/// Statistics aggregate (PRD §4.6 / BRIEF §37).
///
/// Answers "am I making progress?" by combining the running totals from
/// `learning_statistics`, the five-dimension ability scores and the listening
/// error taxonomy into one immutable snapshot. Every read is a bounded, indexed
/// query (ARCHITECTURE §9.4, NFR-11): no full-table scans.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/models/enums/listening_error_type.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/core/models/learning_statistics.dart';
import 'package:ielts_free/core/providers/listening_provider.dart';
import 'package:ielts_free/core/providers/refresh_provider.dart';
import 'package:ielts_free/core/providers/repository_providers.dart';
import 'package:ielts_free/core/storage/repositories/listening_repository.dart';
import 'package:ielts_free/core/storage/repositories/progress_repository.dart';

/// The lowest band the linear estimate can produce (a 0/100 ability).
const double _kBandFloor = 3.0;

/// The band range spanned above [_kBandFloor] (3.0 → 9.0).
const double _kBandSpan = 6.0;

/// Immutable Statistics snapshot.
@immutable
class StatisticsData {
  const StatisticsData({
    this.totalStudyMinutes = 0,
    this.questionsAnswered = 0,
    this.correctCount = 0,
    this.currentStreak = 0,
    this.totalDays = 0,
    this.skillScores = const <SkillType, int>{},
    this.errorCounts = const <ListeningErrorType, int>{},
  });

  /// Lifetime study minutes.
  final int totalStudyMinutes;

  /// Questions answered (as recorded by the statistics row).
  final int questionsAnswered;

  /// Correct answers among [questionsAnswered].
  final int correctCount;

  /// Current study streak in days.
  final int currentStreak;

  /// Lifetime distinct study days.
  final int totalDays;

  /// Five-dimension scores as integers in `[0, 100]`.
  final Map<SkillType, int> skillScores;

  /// Listening errors grouped by cause.
  final Map<ListeningErrorType, int> errorCounts;

  /// Accuracy in `[0, 1]`, or `null` when nothing has been answered yet.
  ///
  /// Returning `null` (rather than `0`) lets the UI show an em dash instead of
  /// a misleading `0%` / `NaN`.
  double? get accuracy =>
      questionsAnswered <= 0 ? null : correctCount / questionsAnswered;

  /// Score for [skill] (`0` when unknown).
  int scoreOf(SkillType skill) => skillScores[skill] ?? 0;

  /// The average of the five headline dimensions, or `null` when every
  /// dimension is still zero (no ability signal at all).
  double? get averageSkillScore {
    int sum = 0;
    bool any = false;
    for (final SkillType skill in SkillType.fiveDimensions) {
      final int value = scoreOf(skill);
      if (value > 0) {
        any = true;
      }
      sum += value;
    }
    if (!any) {
      return null;
    }
    return sum / SkillType.fiveDimensions.length;
  }

  /// Predicted IELTS band in `[3.0, 9.0]`, snapped to the nearest `0.5`.
  ///
  /// The mapping is deliberately simple and explainable: a 0/100 average maps
  /// to band 3.0 and a 100/100 average to band 9.0, linearly in between
  /// (`band = 3 + avg / 100 * 6`). It is an estimate, never an official score —
  /// the page always shows the disclaimer next to it.
  double? get predictedBand {
    final double? average = averageSkillScore;
    if (average == null) {
      return null;
    }
    final double band = _kBandFloor + average / 100 * _kBandSpan;
    return (band * 2).round() / 2;
  }

  /// Total number of logged listening errors.
  int get totalErrors {
    int total = 0;
    for (final int count in errorCounts.values) {
      total += count;
    }
    return total;
  }

  /// Whether any learning signal exists at all.
  bool get hasData =>
      totalStudyMinutes > 0 ||
      questionsAnswered > 0 ||
      currentStreak > 0 ||
      totalDays > 0 ||
      totalErrors > 0 ||
      skillScores.values.any((int score) => score > 0);
}

/// Controller that aggregates the Statistics page.
class StatisticsController extends AsyncNotifier<StatisticsData> {
  @override
  Future<StatisticsData> build() {
    ref.watch(dataRevisionProvider);
    return _load();
  }

  // --- internals ----------------------------------------------------------

  Future<StatisticsData> _load() async {
    const String userId = AppConstants.localUserId;

    final ProgressRepository progress =
        await ref.read(progressRepositoryProvider.future);
    final LearningStatistics? stats = await progress.todayStatistics(userId);
    final Map<SkillType, double> rawScores =
        await progress.skillScoreMap(userId);

    final ListeningRepository listening =
        await ref.read(listeningRepositoryProvider.future);
    final Map<ListeningErrorType, int> errors =
        await listening.errorStats(userId);

    return StatisticsData(
      totalStudyMinutes: stats?.totalStudyMinutes ?? 0,
      questionsAnswered: stats?.questionsAnswered ?? 0,
      correctCount: stats?.correctCount ?? 0,
      currentStreak: stats?.currentStreak ?? 0,
      totalDays: stats?.totalDays ?? 0,
      skillScores: _roundedScores(rawScores),
      errorCounts: errors,
    );
  }

  Map<SkillType, int> _roundedScores(Map<SkillType, double> scores) {
    final Map<SkillType, int> result = <SkillType, int>{};
    for (final SkillType skill in SkillType.fiveDimensions) {
      final double value = scores[skill] ?? 0.0;
      result[skill] = value.round().clamp(0, 100).toInt();
    }
    return result;
  }
}

/// Provider for the Statistics controller.
final AsyncNotifierProvider<StatisticsController, StatisticsData>
    statisticsControllerProvider =
    AsyncNotifierProvider<StatisticsController, StatisticsData>(
  StatisticsController.new,
);
