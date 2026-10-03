import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/vocabulary.dart';
import 'package:ielts_free/features/vocabulary/application/vocabulary_book_controller.dart';
import 'package:ielts_free/features/vocabulary/application/vocabulary_list_controller.dart';
import 'package:ielts_free/features/vocabulary/presentation/vocabulary_topic_order.dart';
import 'package:ielts_free/features/vocabulary/presentation/widgets/topic_illustration.dart';
import 'package:ielts_free/features/vocabulary/presentation/widgets/vocabulary_book_card.dart';
import 'package:ielts_free/shared/widgets/empty_state.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';
import 'package:ielts_free/shared/widgets/primary_button.dart';

/// The vocabulary **book** (browse) page — route `/vocabulary/book`.
///
/// Where the list page is optimised for *studying* (compact rows, difficulty
/// filter), this page is optimised for *browsing*: a picture-book grid of word
/// cards with a topic illustration, a debounced search box and a horizontal
/// topic strip. Selecting a topic also shows that topic's illustration as a
/// banner above the grid.
///
/// Data comes from the shared, paged [VocabularyListController] under the book's
/// own provider, so the 1000-word bank is never rendered in one shot.
class VocabularyBookPage extends ConsumerStatefulWidget {
  const VocabularyBookPage({super.key});

  @override
  ConsumerState<VocabularyBookPage> createState() => _VocabularyBookPageState();
}

class _VocabularyBookPageState extends ConsumerState<VocabularyBookPage> {
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
      ref.read(vocabularyBookControllerProvider.notifier).setQuery(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<VocabularyListState> async =
        ref.watch(vocabularyBookControllerProvider);
    final VocabularyListController controller =
        ref.read(vocabularyBookControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.vocabularyBookTitle)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => ErrorView(
          message: AppStrings.errorGeneric,
          title: AppStrings.vocabularyListErrorTitle,
          onRetry: controller.refresh,
        ),
        data: (VocabularyListState data) => Column(
          children: <Widget>[
            _header(context, data, controller),
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
      ),
    );
  }

  // --- header (search + topic strip) --------------------------------------

  Widget _header(
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
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Text(
                AppStrings.vocabularyFilterTopic,
                style: theme.textTheme.caption.copyWith(
                  color: context.palette.muted,
                ),
              ),
              const Spacer(),
              Text(
                AppStrings.vocabularyCountLabel(data.total),
                style: theme.textTheme.caption.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _TopicChip(
                  label: AppStrings.vocabularyAllTopics,
                  selected: data.topic == null,
                  onTap: () => controller.setTopic(null),
                ),
                for (final String topic in orderVocabularyTopics(data.topics))
                  _TopicChip(
                    label: AppStrings.vocabularyTopicName(topic),
                    selected: data.topic == topic,
                    onTap: () => controller.setTopic(topic),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- body (grid) --------------------------------------------------------

  Widget _body(
    BuildContext context,
    VocabularyListState data,
    VocabularyListController controller,
  ) {
    if (data.items.isEmpty) {
      if (data.error != null) {
        return ErrorView(
          message: AppStrings.errorGeneric,
          title: AppStrings.vocabularyListErrorTitle,
          onRetry: controller.refresh,
        );
      }
      return const EmptyState(
        title: AppStrings.vocabularyEmpty,
        message: AppStrings.vocabularyEmptyHint,
        icon: Icons.collections_bookmark_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final int columns = _columnsFor(constraints.maxWidth);
          return CustomScrollView(
            slivers: <Widget>[
              if (data.topic != null)
                SliverToBoxAdapter(child: _TopicBanner(topic: data.topic!)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.6,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      final Vocabulary word = data.items[index];
                      return VocabularyBookCard(
                        vocabulary: word,
                        topic:
                            word.topics.isEmpty ? null : word.topics.first,
                        onTap: word.id == null
                            ? null
                            : () => context
                                .go('${AppRoutes.vocabulary}/${word.id}'),
                      );
                    },
                    childCount: data.items.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _footer(context, data, controller)),
            ],
          );
        },
      ),
    );
  }

  Widget _footer(
    BuildContext context,
    VocabularyListState data,
    VocabularyListController controller,
  ) {
    if (data.hasMore) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: PrimaryButton(
          label: AppStrings.vocabularyLoadMore,
          isLoading: data.loadingMore,
          onPressed: controller.loadMore,
          expand: true,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(
        AppStrings.vocabularyBookEnd,
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .caption
            .copyWith(color: context.palette.muted),
      ),
    );
  }

  /// Responsive column count: phone 2 / tablet 3 / desktop 4–5.
  int _columnsFor(double width) {
    if (width < 600) {
      return 2;
    }
    if (width < 900) {
      return 3;
    }
    if (width < 1200) {
      return 4;
    }
    return 5;
  }
}

/// The banner shown above the grid while a single topic is selected.
class _TopicBanner extends StatelessWidget {
  const _TopicBanner({required this.topic});

  final String topic;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 140,
            width: double.infinity,
            child: TopicIllustration(
              topic: topic,
              borderRadius: AppRadius.mdAll,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.vocabularyTopicName(topic),
            style: theme.textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}

/// A topic choice chip (Chinese label).
class _TopicChip extends StatelessWidget {
  const _TopicChip({
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
