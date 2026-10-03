import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/enums/listening_error_type.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/features/statistics/application/statistics_controller.dart';
import 'package:ielts_free/shared/widgets/adaptive_layout.dart';
import 'package:ielts_free/shared/widgets/empty_state.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';
import 'package:ielts_free/shared/widgets/stat_tile.dart';

/// Learning statistics ("看得见进步，才坚持得下去").
///
/// Aggregates the running totals, the five-dimension ability radar, the
/// estimated band and the listening error breakdown (PRD §4.6). Hosted by the
/// desktop shell route `/statistics`.
class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<StatisticsData> async =
        ref.watch(statisticsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.statisticsTitle)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace stackTrace) => ErrorView(
          title: AppStrings.statisticsTitle,
          onRetry: () => ref.invalidate(statisticsControllerProvider),
        ),
        data: (StatisticsData data) {
          if (!data.hasData) {
            return const EmptyState(
              icon: Icons.insights_outlined,
              title: AppStrings.statisticsTitle,
              message: AppStrings.statisticsNoData,
            );
          }
          return _StatisticsBody(data: data);
        },
      ),
    );
  }
}

/// The scrollable statistics content.
class _StatisticsBody extends ConsumerWidget {
  const _StatisticsBody({required this.data});

  final StatisticsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(statisticsControllerProvider),
      child: AdaptiveLayout(
        mobile: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            _OverviewCard(data: data),
            const SizedBox(height: AppSpacing.lg),
            _RadarCard(data: data),
            const SizedBox(height: AppSpacing.lg),
            _PredictedBandCard(data: data),
            const SizedBox(height: AppSpacing.lg),
            _ErrorBreakdownCard(data: data),
          ],
        ),
      ),
    );
  }
}

/// Cumulative totals: study time, questions, accuracy and streak.
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.data});

  final StatisticsData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? accuracy = data.accuracy;
    final String accuracyText =
        accuracy == null ? '—' : '${(accuracy * 100).round()}%';

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.statisticsIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.palette.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  label: AppStrings.statisticsTotalTime,
                  value: '${data.totalStudyMinutes}',
                  unit: AppStrings.statisticsMinutes,
                  icon: Icons.schedule,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: StatTile(
                  label: AppStrings.statisticsQuestionsAnswered,
                  value: '${data.questionsAnswered}',
                  icon: Icons.checklist,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  label: AppStrings.statisticsAccuracy,
                  value: accuracyText,
                  icon: Icons.percent,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: StatTile(
                  label: AppStrings.statisticsStreak,
                  value: '${data.currentStreak}',
                  unit: AppStrings.statisticsDays,
                  icon: Icons.local_fire_department,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Five-dimension ability radar (hand-drawn, no chart dependency).
class _RadarCard extends StatelessWidget {
  const _RadarCard({required this.data});

  final StatisticsData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(AppStrings.statisticsRadar, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          _RadarChart(data: data),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final SkillType skill in SkillType.fiveDimensions)
                _LegendItem(
                  label: AppStrings.skillLabel(skill.wire),
                  value: data.scoreOf(skill),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single radar legend entry: a colour dot, the skill label and its value.
class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary,
            shape: BoxShape.circle,
          ),
          child: const SizedBox(
            width: AppSpacing.sm,
            height: AppSpacing.sm,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$label $value',
          style: theme.textTheme.caption.copyWith(
            color: context.palette.muted,
          ),
        ),
      ],
    );
  }
}

/// The radar canvas, sized and wired to the current theme.
class _RadarChart extends StatelessWidget {
  const _RadarChart({required this.data});

  final StatisticsData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<int> values = <int>[
      for (final SkillType skill in SkillType.fiveDimensions)
        data.scoreOf(skill),
    ];
    final List<String> labels = <String>[
      for (final SkillType skill in SkillType.fiveDimensions)
        AppStrings.skillLabel(skill.wire),
    ];

    return SizedBox(
      height: 260,
      child: CustomPaint(
        size: Size.infinite,
        painter: _RadarPainter(
          values: values,
          labels: labels,
          gridColor: theme.colorScheme.outlineVariant,
          fillColor: theme.colorScheme.secondary.withValues(alpha: 0.16),
          strokeColor: theme.colorScheme.secondary,
          labelStyle: theme.textTheme.caption.copyWith(
            color: context.palette.muted,
          ),
        ),
      ),
    );
  }
}

/// Draws a regular pentagon grid plus the five-dimension data polygon.
class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.values,
    required this.labels,
    required this.gridColor,
    required this.fillColor,
    required this.strokeColor,
    required this.labelStyle,
  });

  /// Dimension values in `[0, 100]`, one per axis.
  final List<int> values;

  /// Axis labels, one per axis.
  final List<String> labels;

  final Color gridColor;
  final Color fillColor;
  final Color strokeColor;
  final TextStyle labelStyle;

  /// Number of axes (the five headline dimensions).
  static const int _sides = 5;

  /// Ring fractions drawn from the centre outwards.
  static const List<double> _rings = <double>[0.25, 0.5, 0.75, 1.0];

  /// Margin reserved outside the outer ring for the axis labels.
  static const double _labelInset = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = math.min(size.width, size.height) / 2 - _labelInset;
    if (radius <= 0 || values.length != _sides) {
      return;
    }
    final Offset center = Offset(size.width / 2, size.height / 2);

    final Paint gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = gridColor;

    for (final double ring in _rings) {
      canvas.drawPath(_polygon(center, radius * ring), gridPaint);
    }
    for (int i = 0; i < _sides; i++) {
      canvas.drawLine(center, _pointOn(center, radius, i), gridPaint);
    }

    final Path data = Path();
    for (int i = 0; i < _sides; i++) {
      final Offset point = _pointOn(center, radius * _ratioOf(i), i);
      if (i == 0) {
        data.moveTo(point.dx, point.dy);
      } else {
        data.lineTo(point.dx, point.dy);
      }
    }
    data.close();
    canvas.drawPath(
      data,
      Paint()
        ..style = PaintingStyle.fill
        ..color = fillColor,
    );
    canvas.drawPath(
      data,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = strokeColor,
    );

    final Paint dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = strokeColor;
    for (int i = 0; i < _sides; i++) {
      canvas.drawCircle(
        _pointOn(center, radius * _ratioOf(i), i),
        AppSpacing.xs / 2,
        dotPaint,
      );
    }

    for (int i = 0; i < _sides; i++) {
      _paintLabel(canvas, _pointOn(center, radius + AppSpacing.lg, i), labels[i]);
    }
  }

  double _ratioOf(int index) => values[index].clamp(0, 100) / 100.0;

  /// A closed polygon whose vertices sit on the [radius] ring.
  Path _polygon(Offset center, double radius) {
    final Path path = Path();
    for (int i = 0; i < _sides; i++) {
      final Offset point = _pointOn(center, radius, i);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  /// The [index]-th axis vertex, starting at the top and going clockwise.
  Offset _pointOn(Offset center, double radius, int index) {
    final double angle = -math.pi / 2 + (2 * math.pi / _sides) * index;
    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  }

  void _paintLabel(Canvas canvas, Offset center, String text) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.labels != labels ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.labelStyle != labelStyle;
}

/// The estimated IELTS band derived from the five-dimension average.
class _PredictedBandCard extends StatelessWidget {
  const _PredictedBandCard({required this.data});

  final StatisticsData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? band = data.predictedBand;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.statisticsPredictedBand,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            band == null ? '—' : band.toStringAsFixed(1),
            style: theme.textTheme.displayLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.statisticsPredictedHint,
            style: theme.textTheme.caption.copyWith(
              color: context.palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Listening errors grouped by cause, as horizontal bars.
class _ErrorBreakdownCard extends StatelessWidget {
  const _ErrorBreakdownCard({required this.data});

  final StatisticsData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int maxCount = _maxErrorCount(data.errorCounts);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.statisticsErrorBreakdown,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          if (data.totalErrors <= 0)
            Text(
              AppStrings.statisticsNoData,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.palette.muted,
              ),
            )
          else
            for (int i = 0; i < ListeningErrorType.values.length; i++) ...<Widget>[
              _ErrorBar(
                label: ListeningErrorType.values[i].label,
                count: data.errorCounts[ListeningErrorType.values[i]] ?? 0,
                maxCount: maxCount,
              ),
              if (i != ListeningErrorType.values.length - 1)
                const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }

  int _maxErrorCount(Map<ListeningErrorType, int> counts) {
    int max = 0;
    for (final int count in counts.values) {
      if (count > max) {
        max = count;
      }
    }
    return max;
  }
}

/// One labelled error-count bar, scaled against the largest count.
class _ErrorBar extends StatelessWidget {
  const _ErrorBar({
    required this.label,
    required this.count,
    required this.maxCount,
  });

  final String label;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double ratio = maxCount <= 0 ? 0.0 : count / maxCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$count',
              style: theme.textTheme.label.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: AppRadius.smAll,
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: AppSpacing.sm,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(context.palette.warning),
          ),
        ),
      ],
    );
  }
}
