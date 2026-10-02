import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/features/vocabulary/application/vocabulary_detail_controller.dart';
import 'package:ielts_free/features/vocabulary/presentation/widgets/word_card.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';

/// The vocabulary detail pane (PRD §4.3 / BRIEF §14).
///
/// Renders the full [WordCard] and the action bar
/// 🔊发音 / ⭐收藏 / ✓掌握 / ✗不认识. Shared by the desktop detail page and the
/// mobile detail route.
///
/// **Audio choice (no network, no new dependency):** V0.1 ships no TTS package,
/// and pulling one in would add a platform plugin to a project that must stay
/// dependency-light and fully offline. Rather than fail silently, the 🔊 button
/// surfaces [AppStrings.vocabularySpeakUnavailable] — an honest "not available
/// yet" placeholder. A platform-TTS implementation can be dropped in behind this
/// button later without touching the rest of the page.
class VocabularyDetailPane extends ConsumerWidget {
  const VocabularyDetailPane({super.key, required this.vocabularyId});

  /// Id of the word to display.
  final int vocabularyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<VocabularyDetailState> async =
        ref.watch(vocabularyDetailControllerProvider(vocabularyId));
    final VocabularyDetailController controller =
        ref.read(vocabularyDetailControllerProvider(vocabularyId).notifier);

    return async.when(
      loading: () => const LoadingView(),
      error: (Object error, StackTrace _) => const ErrorView(
        message: AppStrings.errorGeneric,
        title: AppStrings.vocabularyDetailErrorTitle,
      ),
      data: (VocabularyDetailState data) => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          WordCard(
            vocabulary: data.vocabulary,
            topics: data.topics,
            memoryLevel: data.memoryLevel,
            isMastered: data.isMastered,
          ),
          const SizedBox(height: AppSpacing.lg),
          _ActionBar(
            isFavorite: data.isFavorite,
            busy: data.busy,
            onSpeak: () => _speak(context),
            onToggleFavorite: controller.toggleFavorite,
            onKnown: controller.markKnown,
            onUnknown: controller.markUnknown,
          ),
          if (data.error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              data.error!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  void _speak(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.vocabularySpeakUnavailable)),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.isFavorite,
    required this.busy,
    required this.onSpeak,
    required this.onToggleFavorite,
    required this.onKnown,
    required this.onUnknown,
  });

  final bool isFavorite;
  final bool busy;
  final VoidCallback onSpeak;
  final VoidCallback onToggleFavorite;
  final VoidCallback onKnown;
  final VoidCallback onUnknown;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: onSpeak,
          icon: const Icon(Icons.volume_up_outlined),
          label: const Text(AppStrings.speak),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onToggleFavorite,
          icon: Icon(isFavorite ? Icons.star : Icons.star_border),
          label: const Text(AppStrings.favorite),
        ),
        FilledButton.tonalIcon(
          onPressed: busy ? null : onKnown,
          icon: const Icon(Icons.check),
          label: const Text(AppStrings.master),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onUnknown,
          icon: const Icon(Icons.close),
          label: const Text(AppStrings.dontKnow),
        ),
      ],
    );
  }
}
