import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/daily_task.dart';
import 'package:ielts_free/core/models/enums/task_type.dart';
import 'package:ielts_free/shared/widgets/empty_state.dart';
import 'package:ielts_free/shared/widgets/primary_button.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// Dashboard "今日任务" list.
///
/// Each row opens the matching training; when the day has no tasks yet the user
/// can generate them right here.
class TodayTasksCard extends StatelessWidget {
  const TodayTasksCard({
    super.key,
    required this.tasks,
    this.onGenerate,
    this.busy = false,
  });

  /// Today's tasks (already persisted).
  final List<DailyTask> tasks;

  /// Called when the user taps "生成今日任务".
  final VoidCallback? onGenerate;

  /// Whether generation is running.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.dashboardTodayTasks,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (tasks.isEmpty)
            EmptyState(
              icon: Icons.checklist_outlined,
              message: AppStrings.dashboardNoTasks,
              action: onGenerate == null
                  ? null
                  : PrimaryButton(
                      label: AppStrings.dashboardGeneratePlan,
                      icon: Icons.auto_awesome,
                      isLoading: busy,
                      onPressed: onGenerate,
                    ),
            )
          else
            for (int i = 0; i < tasks.length; i++) ...<Widget>[
              if (i > 0) const Divider(height: AppSpacing.lg),
              _TaskRow(task: tasks[i]),
            ],
        ],
      ),
    );
  }
}

/// One tappable task row.
class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final DailyTask task;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool done = task.status.isDone;
    final int total = task.itemCount ?? 0;
    final String title = task.title ?? '';

    return InkWell(
      borderRadius: AppRadius.smAll,
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: done ? context.palette.success : context.palette.muted,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? context.palette.muted : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (total > 0) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${task.completedCount}/$total',
                      style: theme.textTheme.caption.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: context.palette.muted,
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    switch (task.taskType) {
      case TaskType.vocabReview:
      case TaskType.vocabPractice:
        context.go(AppRoutes.vocabularyPractice);
      case TaskType.reading:
        context.go(AppRoutes.reading);
      case TaskType.mistakeReview:
        context.go(AppRoutes.mistakes);
      case null:
        context.go(AppRoutes.practice);
    }
  }
}
