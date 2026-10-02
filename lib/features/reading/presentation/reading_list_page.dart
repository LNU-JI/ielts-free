import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/reading_passage.dart';
import 'package:ielts_free/features/reading/application/reading_list_controller.dart';
import 'package:ielts_free/shared/widgets/adaptive_layout.dart';
import 'package:ielts_free/shared/widgets/empty_state.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';
import 'package:ielts_free/shared/widgets/primary_button.dart';

/// Reading list (desktop shell route `/reading`).
class ReadingListPage extends ConsumerWidget {
  const ReadingListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ReadingListState> async =
        ref.watch(readingListControllerProvider);
    final ReadingListController controller =
        ref.read(readingListControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.readingTitle)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => ErrorView(
          title: AppStrings.readingListErrorTitle,
          onRetry: controller.refresh,
        ),
        data: (ReadingListState data) => ContentContainer(
          maxWidth: 840,
          child: Column(
            children: <Widget>[
              _filters(context, data, controller),
              Expanded(child: _list(context, data, controller)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filters(
    BuildContext context,
    ReadingListState data,
    ReadingListController controller,
  ) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.vocabularyFilterTopic,
            style: theme.textTheme.caption.copyWith(color: context.palette.muted),
          ),
          const SizedBox(height: AppSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _FilterChip(
                  label: AppStrings.vocabularyAllTopics,
                  selected: data.topic == null,
                  onTap: () => controller.setTopic(null),
                ),
                for (final String topic in data.topics)
                  _FilterChip(
                    label: topic,
                    selected: data.topic == topic,
                    onTap: () => controller.setTopic(topic),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.vocabularyFilterDifficulty,
            style: theme.textTheme.caption.copyWith(color: context.palette.muted),
          ),
          const SizedBox(height: AppSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _FilterChip(
                  label: AppStrings.vocabularyAllTopics,
                  selected: data.difficulty == null,
                  onTap: () => controller.setDifficulty(null),
                ),
                for (int level = 1; level <= 5; level++)
                  _FilterChip(
                    label: '$level',
                    selected: data.difficulty == level,
                    onTap: () => controller.setDifficulty(level),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(
    BuildContext context,
    ReadingListState data,
    ReadingListController controller,
  ) {
    if (data.items.isEmpty) {
      return const EmptyState(
        icon: Icons.article_outlined,
        title: AppStrings.readingListEmpty,
        message: AppStrings.readingListEmptyHint,
      );
    }

    final int itemCount = data.items.length + (data.hasMore ? 1 : 0);
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: itemCount,
        itemBuilder: (BuildContext context, int index) {
          if (index >= data.items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: PrimaryButton(
                label: AppStrings.vocabularyLoadMore,
                isLoading: data.loadingMore,
                onPressed: controller.loadMore,
                expand: true,
              ),
            );
          }
          final ReadingPassage passage = data.items[index];
          return _PassageTile(
            passage: passage,
            onTap: () => context.go('${AppRoutes.reading}/${passage.id}'),
          );
        },
      ),
    );
  }
}

class _PassageTile extends StatelessWidget {
  const _PassageTile({required this.passage, required this.onTap});

  final ReadingPassage passage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
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
              Text(
                passage.title,
                style: theme.textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  if (passage.topic != null && passage.topic!.isNotEmpty) ...<Widget>[
                    Text(
                      passage.topic!,
                      style: theme.textTheme.caption.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Text(
                    AppStrings.vocabularyDifficultyLabel(passage.difficulty),
                    style: theme.textTheme.caption.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                  if (passage.readingTimeSec != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      AppStrings.readingTimeLabel(
                        (passage.readingTimeSec! / 60).round(),
                      ),
                      style: theme.textTheme.caption.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
