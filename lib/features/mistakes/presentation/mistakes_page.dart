import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/enums/ref_type.dart';
import 'package:ielts_free/core/models/mistake.dart';
import 'package:ielts_free/features/mistakes/application/mistake_labels.dart';
import 'package:ielts_free/features/mistakes/application/mistakes_controller.dart';
import 'package:ielts_free/shared/widgets/adaptive_layout.dart';
import 'package:ielts_free/shared/widgets/empty_state.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/linear_progress_bar.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';
import 'package:ielts_free/shared/widgets/primary_button.dart';

/// Mistakes list with filters (mobile shell route `/mistakes`, PRD §4.6).
///
/// Shows each mistake's type / error type, wrong count and mastery, filterable by
/// 全部 / 词汇 / 阅读, with a "重做错题" shortcut into the first active mistake.
class MistakesPage extends ConsumerWidget {
  const MistakesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MistakesState> async =
        ref.watch(mistakesControllerProvider);
    final MistakesController controller =
        ref.read(mistakesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.mistakesTitle)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => ErrorView(
          title: AppStrings.mistakesErrorTitle,
          onRetry: controller.refresh,
        ),
        data: (MistakesState data) => ContentContainer(
          maxWidth: 840,
          child: Column(
            children: <Widget>[
              _filters(context, data, controller),
              Expanded(child: _list(context, data, controller)),
              if (data.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: PrimaryButton(
                    label: AppStrings.mistakesRedoAll,
                    icon: Icons.replay,
                    expand: true,
                    onPressed: () => _redoFirst(context, data),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _redoFirst(BuildContext context, MistakesState data) {
    for (final Mistake mistake in data.items) {
      final int? id = mistake.id;
      if (id != null && !mistake.isMastered) {
        context.go('${AppRoutes.mistakes}/$id');
        return;
      }
    }
    if (data.items.isNotEmpty && data.items.first.id != null) {
      context.go('${AppRoutes.mistakes}/${data.items.first.id}');
    }
  }

  Widget _filters(
    BuildContext context,
    MistakesState data,
    MistakesController controller,
  ) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          _FilterChip(
            label: AppStrings.mistakesFilterAll,
            selected: data.filter == null,
            onTap: () => controller.setFilter(null),
          ),
          _FilterChip(
            label: AppStrings.mistakesFilterVocabulary,
            selected: data.filter == RefType.vocabulary,
            onTap: () => controller.setFilter(RefType.vocabulary),
          ),
          _FilterChip(
            label: AppStrings.mistakesFilterReading,
            selected: data.filter == RefType.reading,
            onTap: () => controller.setFilter(RefType.reading),
          ),
          const Spacer(),
          Text(
            AppStrings.mistakesCountLabel(data.activeCount),
            style: theme.textTheme.caption.copyWith(color: context.palette.muted),
          ),
        ],
      ),
    );
  }

  Widget _list(
    BuildContext context,
    MistakesState data,
    MistakesController controller,
  ) {
    if (data.items.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_outline,
        title: AppStrings.mistakesEmpty,
        message: AppStrings.mistakesEmptyHint,
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
          final Mistake mistake = data.items[index];
          return _MistakeTile(
            mistake: mistake,
            onTap: mistake.id == null
                ? null
                : () => context.go('${AppRoutes.mistakes}/${mistake.id}'),
          );
        },
      ),
    );
  }
}

class _MistakeTile extends StatelessWidget {
  const _MistakeTile({required this.mistake, this.onTap});

  final Mistake mistake;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String type = MistakeLabels.questionType(mistake.questionType);
    final String errorType = MistakeLabels.errorType(mistake.errorType);

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
                      <String>[type, errorType]
                          .where((String s) => s.isNotEmpty)
                          .join(' · '),
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (mistake.isMastered)
                    Text(
                      AppStrings.mistakesMasteredTag,
                      style: theme.textTheme.caption.copyWith(
                        color: context.palette.success,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.mistakesWrongCount(mistake.wrongCount),
                style: theme.textTheme.caption.copyWith(
                  color: context.palette.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              LinearProgressBar(
                value: mistake.mastery,
                caption: Text(
                  AppStrings.mistakesMasteryPercent(
                    (mistake.mastery * 100).round(),
                  ),
                  style: theme.textTheme.caption.copyWith(
                    color: context.palette.muted,
                  ),
                ),
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
