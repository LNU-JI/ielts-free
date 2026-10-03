import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/vocabulary.dart';
import 'package:ielts_free/features/vocabulary/presentation/widgets/topic_illustration.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// One word rendered as a picture-book card for the vocabulary book grid.
///
/// Layout: a topic illustration on top, then the head word (large), the
/// phonetic transcription, a single-line Chinese meaning and the difficulty /
/// CEFR tags. The whole card taps through to the existing detail page.
class VocabularyBookCard extends StatelessWidget {
  const VocabularyBookCard({
    super.key,
    required this.vocabulary,
    this.topic,
    this.onTap,
  });

  /// The word to display.
  final Vocabulary vocabulary;

  /// The word's own first topic slug, used for the card illustration, or `null`
  /// when the word carries no topics (the illustration then falls back to a
  /// neutral placeholder).
  final String? topic;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  /// Width / height of the illustration strip at the top of the card.
  static const double _imageAspect = 16 / 10;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? phonetic = vocabulary.phonetic;

    return SectionCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: _imageAspect,
            child: TopicIllustration(
              topic: topic,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.md),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        vocabulary.word,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (phonetic != null && phonetic.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            phonetic,
                            style: theme.textTheme.caption.copyWith(
                              color: context.palette.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        vocabulary.meaningCn,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.palette.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  _tags(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tags() {
    final String? cefr = vocabulary.cefr;
    // A single, non-wrapping row: keeps the card height predictable even at the
    // largest font scale (1.3×), where a wrapping tag row would overflow.
    return Row(
      children: <Widget>[
        Flexible(
          child: _Tag(
            text: AppStrings.vocabularyDifficultyLabel(vocabulary.difficulty),
          ),
        ),
        if (cefr != null && cefr.isNotEmpty) ...<Widget>[
          const SizedBox(width: AppSpacing.xs),
          Flexible(child: _Tag(text: cefr)),
        ],
      ],
    );
  }
}

/// A small, low-emphasis tag used for the difficulty / CEFR chips.
class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.caption.copyWith(color: context.palette.muted),
      ),
    );
  }
}
