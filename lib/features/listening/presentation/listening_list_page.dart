import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/listening_section.dart';
import 'package:ielts_free/features/listening/application/listening_list_controller.dart';
import 'package:ielts_free/shared/widgets/adaptive_layout.dart';
import 'package:ielts_free/shared/widgets/empty_state.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';

/// Listening section picker (desktop shell route `/listening`).
///
/// Lists every intensive-listening section with its IELTS part, scene and
/// difficulty, plus a "practised" badge for sections the learner has already
/// logged a mistake in.
class ListeningListPage extends ConsumerWidget {
  const ListeningListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ListeningListState> async =
        ref.watch(listeningListControllerProvider);
    final ListeningListController controller =
        ref.read(listeningListControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.listeningTitle)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => ErrorView(
          title: AppStrings.listeningTitle,
          onRetry: controller.refresh,
        ),
        data: (ListeningListState data) => _content(context, data, controller),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    ListeningListState data,
    ListeningListController controller,
  ) {
    if (data.items.isEmpty) {
      return const EmptyState(
        icon: Icons.headphones_outlined,
        message: AppStrings.listeningEmpty,
      );
    }
    final ThemeData theme = Theme.of(context);
    return ContentContainer(
      maxWidth: 840,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              AppStrings.listeningIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.palette.muted,
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                itemCount: data.items.length,
                itemBuilder: (BuildContext context, int index) {
                  final ListeningSection section = data.items[index];
                  return _SectionTile(
                    section: section,
                    practiced: data.isPracticed(section.id),
                    onTap: () =>
                        context.go('${AppRoutes.listening}/${section.id}'),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.section,
    required this.practiced,
    required this.onTap,
  });

  final ListeningSection section;
  final bool practiced;
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
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Text(
                      section.partLabel,
                      style: theme.textTheme.caption.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      section.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (practiced) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: context.palette.success,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      AppStrings.done,
                      style: theme.textTheme.caption.copyWith(
                        color: context.palette.success,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  if (section.scene != null && section.scene!.isNotEmpty) ...<Widget>[
                    Text(
                      section.scene!,
                      style: theme.textTheme.caption.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  if (section.difficulty != null)
                    Text(
                      AppStrings.vocabularyDifficultyLabel(section.difficulty!),
                      style: theme.textTheme.caption.copyWith(
                        color: context.palette.muted,
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
