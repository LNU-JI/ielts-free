import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/enums/speaking_part.dart';
import 'package:ielts_free/features/speaking/application/speaking_list_controller.dart';
import 'package:ielts_free/shared/widgets/adaptive_layout.dart';
import 'package:ielts_free/shared/widgets/empty_state.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';
import 'package:ielts_free/shared/widgets/primary_button.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';
import 'package:ielts_free/shared/widgets/section_header.dart';

/// Speaking topic bank, grouped by Part 1 / 2 / 3 (desktop shell route
/// `/speaking`).
class SpeakingListPage extends ConsumerWidget {
  const SpeakingListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SpeakingListState> async =
        ref.watch(speakingListControllerProvider);
    final SpeakingListController controller =
        ref.read(speakingListControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.speakingTitle)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => ErrorView(
          title: AppStrings.speakingTitle,
          onRetry: controller.refresh,
        ),
        data: (SpeakingListState data) => ContentContainer(
          maxWidth: 840,
          child: data.entries.isEmpty
              ? const EmptyState(
                  icon: Icons.record_voice_over_outlined,
                  message: AppStrings.speakingEmpty,
                )
              : _body(context, data, controller),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    SpeakingListState data,
    SpeakingListController controller,
  ) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
            AppStrings.speakingIntro,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.palette.muted,
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              children: <Widget>[
                for (final SpeakingPart part in SpeakingPart.values)
                  ..._section(context, data, part),
                if (data.hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: PrimaryButton(
                      label: AppStrings.vocabularyLoadMore,
                      isLoading: data.loadingMore,
                      onPressed: controller.loadMore,
                      expand: true,
                    ),
                  ),
                if (data.error != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    data.error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _section(
    BuildContext context,
    SpeakingListState data,
    SpeakingPart part,
  ) {
    final List<SpeakingTopicEntry> entries = data.entriesFor(part);
    if (entries.isEmpty) {
      return const <Widget>[];
    }
    return <Widget>[
      SectionHeader(title: '${part.label} · ${part.description}'),
      for (final SpeakingTopicEntry entry in entries)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _TopicTile(
            entry: entry,
            onTap: () => context.go('${AppRoutes.speaking}/${entry.topic.id}'),
          ),
        ),
      const SizedBox(height: AppSpacing.md),
    ];
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.entry, required this.onTap});

  final SpeakingTopicEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SectionCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            entry.topic.title,
            style: theme.textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              if (entry.topic.topic.isNotEmpty) ...<Widget>[
                Expanded(
                  child: Text(
                    entry.topic.topic,
                    style: theme.textTheme.caption.copyWith(
                      color: context.palette.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),
              Icon(
                Icons.format_list_numbered,
                size: 16,
                color: context.palette.muted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${entry.questionCount} ${AppStrings.questionsUnit}',
                style: theme.textTheme.caption.copyWith(
                  color: context.palette.muted,
                ),
              ),
              if (entry.practised) ...<Widget>[
                const SizedBox(width: AppSpacing.md),
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: context.palette.success,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
