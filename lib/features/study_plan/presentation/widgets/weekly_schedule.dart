import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/features/study_plan/application/study_plan_controller.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// The "本周安排" list — seven rows, today highlighted.
///
/// The plan is not fixed: the daily tasks are recomputed by the algorithm every
/// day (BRIEF §36), so the rows are a preview rather than a frozen schedule.
class WeeklySchedule extends StatelessWidget {
  const WeeklySchedule({super.key, required this.days});

  /// Seven day previews, today first.
  final List<PlanDayPreview> days;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.studyPlanWeekSchedule,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          if (days.isEmpty)
            Text(
              AppStrings.studyPlanEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.palette.muted,
              ),
            )
          else
            for (int i = 0; i < days.length; i++) ...<Widget>[
              if (i > 0) const Divider(height: AppSpacing.lg),
              _DayRow(day: days[i]),
            ],
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.studyPlanDynamicNote,
            style: theme.textTheme.caption.copyWith(
              color: context.palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// One weekday row.
class _DayRow extends StatelessWidget {
  const _DayRow({required this.day});

  final PlanDayPreview day;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color labelColor =
        day.isToday ? theme.colorScheme.secondary : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 48,
            child: Text(
              day.weekdayLabel,
              style: theme.textTheme.label.copyWith(
                color: labelColor,
                fontWeight: day.isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              day.summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.palette.muted,
              ),
            ),
          ),
          if (day.isToday)
            Icon(Icons.today_outlined, size: 16, color: labelColor),
        ],
      ),
    );
  }
}
