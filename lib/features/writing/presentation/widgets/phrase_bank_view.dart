import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/writing_phrase.dart';
import 'package:ielts_free/features/writing/application/writing_controller.dart';
import 'package:ielts_free/shared/widgets/empty_state.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';
import 'package:ielts_free/shared/widgets/section_header.dart';

/// The phrase bank: sentence patterns grouped by category, each collectable
/// into the phrase book with one tap.
class PhraseBankView extends ConsumerWidget {
  const PhraseBankView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PhraseBankState> async =
        ref.watch(phraseBankControllerProvider);
    final PhraseBankController controller =
        ref.read(phraseBankControllerProvider.notifier);

    return async.when(
      loading: () => const LoadingView(),
      error: (Object error, StackTrace _) => ErrorView(
        title: AppStrings.writingPhraseBank,
        onRetry: () => ref.invalidate(phraseBankControllerProvider),
      ),
      data: (PhraseBankState data) {
        if (data.isEmpty) {
          return const EmptyState(
            icon: Icons.format_quote_outlined,
            title: AppStrings.writingPhraseBank,
            message: AppStrings.writingEmpty,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final PhraseGroup group in data.groups) ...<Widget>[
              SectionHeader(title: group.category),
              for (final WritingPhrase phrase in group.phrases)
                _PhraseTile(
                  phrase: phrase,
                  bookmarked: data.isBookmarked(phrase.id),
                  onBookmark: () => controller.bookmark(phrase),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (data.error != null)
              Text(
                data.error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
          ],
        );
      },
    );
  }
}

class _PhraseTile extends StatelessWidget {
  const _PhraseTile({
    required this.phrase,
    required this.bookmarked,
    required this.onBookmark,
  });

  final WritingPhrase phrase;
  final bool bookmarked;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? meaning = phrase.meaningCn;
    final String? example = phrase.example;
    final String? band = phrase.band;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(phrase.phrase, style: theme.textTheme.titleSmall),
            if (meaning != null && meaning.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                meaning,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ],
            if (example != null && example.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(example, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                if (band != null && band.isNotEmpty)
                  Text(
                    band,
                    style: theme.textTheme.caption.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: bookmarked ? null : onBookmark,
                  icon: Icon(
                    bookmarked
                        ? Icons.bookmark_added
                        : Icons.bookmark_add_outlined,
                  ),
                  label: Text(
                    bookmarked
                        ? AppStrings.writingSaved
                        : AppStrings.writingAddPhrase,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
