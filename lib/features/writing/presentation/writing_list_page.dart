import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/models/writing_attempt.dart';
import 'package:ielts_free/core/models/writing_task.dart';
import 'package:ielts_free/features/writing/application/writing_controller.dart';
import 'package:ielts_free/shared/widgets/adaptive_layout.dart';
import 'package:ielts_free/shared/widgets/empty_state.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';

/// Writing task list (desktop shell route `/writing`).
///
/// Groups the bank by Task 1 / Task 2 and marks the tasks that already have a
/// saved attempt.
class WritingListPage extends ConsumerWidget {
  const WritingListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WritingListState> async =
        ref.watch(writingListControllerProvider);
    final WritingListController controller =
        ref.read(writingListControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.writingTitle)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => ErrorView(
          title: AppStrings.writingTitle,
          onRetry: controller.refresh,
        ),
        data: (WritingListState data) {
          if (data.isEmpty) {
            return const EmptyState(
              icon: Icons.edit_outlined,
              title: AppStrings.writingTitle,
              message: AppStrings.writingEmpty,
            );
          }
          return ContentContainer(
            maxWidth: 840,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.writingIntro,
                  style: Theme.of(context).textTheme.caption.copyWith(
                        color: context.palette.muted,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(child: _list(context, data, controller)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _list(
    BuildContext context,
    WritingListState data,
    WritingListController controller,
  ) {
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: <Widget>[
          _section(context, data, AppStrings.writingTask1, AppStrings.writingTask1Hint, data.task1),
          const SizedBox(height: AppSpacing.lg),
          _section(context, data, AppStrings.writingTask2, AppStrings.writingTask2Hint, data.task2),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context,
    WritingListState data,
    String title,
    String hint,
    List<WritingTask> tasks,
  ) {
    final ThemeData theme = Theme.of(context);
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          hint,
          style: theme.textTheme.caption.copyWith(color: context.palette.muted),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final WritingTask task in tasks)
          _TaskTile(
            task: task,
            attempt: data.attemptFor(task.id),
            onTap: () => context.go('${AppRoutes.writing}/${task.id}'),
          ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.attempt,
    required this.onTap,
  });

  final WritingTask task;
  final WritingAttempt? attempt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? chartType = asString(task.chartData?['type']);
    final WritingAttempt? latest = attempt;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (latest != null)
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: context.palette.success,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  if (task.isTask1 && chartType != null && chartType.isNotEmpty) ...<Widget>[
                    Text(
                      '${AppStrings.writingChart} · ${AppStrings.chartTypeLabel(chartType)}',
                      style: theme.textTheme.caption.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  if (task.difficulty != null)
                    Text(
                      AppStrings.vocabularyDifficultyLabel(task.difficulty!),
                      style: theme.textTheme.caption.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                  const Spacer(),
                  if (latest != null)
                    Text(
                      AppStrings.writingSaved,
                      style: theme.textTheme.caption.copyWith(
                        color: context.palette.success,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
