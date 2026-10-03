import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/vocabulary.dart';
import 'package:ielts_free/features/vocabulary/application/vocabulary_list_controller.dart';
import 'package:ielts_free/features/vocabulary/presentation/vocabulary_topic_order.dart';
import 'package:ielts_free/shared/widgets/empty_state.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';
import 'package:ielts_free/shared/widgets/primary_button.dart';

/// The paginated, filterable vocabulary list (PRD §4.1 / BRIEF §13, FR-023).
///
/// Shared by the list page and the desktop detail page so both panes stay in
/// sync. Search is debounced (300 ms) and every filter change reloads from
/// page 1; additional pages load lazily.
class VocabularyListPane extends ConsumerStatefulWidget {
  const VocabularyListPane({
    super.key,
    this.selectedId,
    this.onSelect,
    this.onRefresh,
  });

  /// Id of the word currently shown in the detail pane (highlighted in the list).
  final int? selectedId;

  /// Called when a word is tapped.
  final ValueChanged<int>? onSelect;

  /// Called when the user pulls to refresh.
  final Future<void> Function()? onRefresh;

  @override
  ConsumerState<VocabularyListPane> createState() => _VocabularyListPaneState();
}

class _VocabularyListPaneState extends ConsumerState<VocabularyListPane> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(vocabularyListControllerProvider.notifier).setQuery(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<VocabularyListState> async =
        ref.watch(vocabularyListControllerProvider);
    final VocabularyListController controller =
        ref.read(vocabularyListControllerProvider.notifier);

    return async.when(
      loading: () => const LoadingView(),
      error: (Object error, StackTrace _) => ErrorView(
        message: AppStrings.errorGeneric,
        title: AppStrings.vocabularyListErrorTitle,
        onRetry: controller.refresh,
      ),
      data: (VocabularyListState data) => Column(
        children: <Widget>[
          _filters(context, data, controller),
          if (data.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                data.error!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(child: _body(context, data, controller)),
        ],
      ),
    );
  }

  Widget _filters(
    BuildContext context,
    VocabularyListState data,
    VocabularyListController controller,
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
          TextField(
            controller: _search,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: AppStrings.vocabularySearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: data.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _search.clear();
                        controller.setQuery('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
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
                for (final String topic in orderVocabularyTopics(data.topics))
                  _FilterChip(
                    label: AppStrings.vocabularyTopicName(topic),
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

  Widget _body(
    BuildContext context,
    VocabularyListState data,
    VocabularyListController controller,
  ) {
    if (data.items.isEmpty) {
      return const EmptyState(
        title: AppStrings.vocabularyEmpty,
        message: AppStrings.vocabularyEmptyHint,
        icon: Icons.menu_book_outlined,
      );
    }

    final int itemCount = data.items.length + (data.hasMore ? 1 : 0);
    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? controller.refresh,
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
          final Vocabulary word = data.items[index];
          return _VocabularyTile(
            vocabulary: word,
            selected: widget.selectedId != null && widget.selectedId == word.id,
            onTap: word.id == null
                ? null
                : () => widget.onSelect?.call(word.id!),
          );
        },
      ),
    );
  }
}

class _VocabularyTile extends StatelessWidget {
  const _VocabularyTile({
    required this.vocabulary,
    required this.selected,
    this.onTap,
  });

  final Vocabulary vocabulary;
  final bool selected;
  final VoidCallback? onTap;

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
            color: selected ? theme.colorScheme.secondaryContainer : null,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      vocabulary.word,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (vocabulary.partOfSpeech != null &&
                      vocabulary.partOfSpeech!.isNotEmpty)
                    Text(
                      vocabulary.partOfSpeech!,
                      style: theme.textTheme.caption.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                vocabulary.meaningCn,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.palette.muted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
