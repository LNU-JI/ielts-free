import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/reading_passage.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// The passage column of the reading page (PRD §4.5).
///
/// Renders the title, topic / difficulty / band chips and the full passage text.
/// The text is selectable so learners can copy evidence while reading.
class PassageView extends StatelessWidget {
  const PassageView({super.key, required this.passage});

  /// The passage to display.
  final ReadingPassage passage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasText = passage.passage.trim().isNotEmpty;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(passage.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              if (passage.topic != null && passage.topic!.isNotEmpty)
                _Tag(text: passage.topic!),
              _Tag(text: AppStrings.vocabularyDifficultyLabel(passage.difficulty)),
              if (passage.band != null && passage.band!.isNotEmpty)
                _Tag(text: passage.band!),
              if (passage.readingTimeSec != null)
                _Tag(
                  text: AppStrings.readingTimeLabel(
                    (passage.readingTimeSec! / 60).round(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (hasText)
            SelectableText(
              passage.passage,
              style: theme.textTheme.bodyLarge,
            )
          else
            Text(
              AppStrings.readingPassageEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.palette.muted,
              ),
            ),
        ],
      ),
    );
  }
}

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
        borderRadius: AppRadius.smAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        text,
        style: theme.textTheme.caption.copyWith(color: context.palette.muted),
      ),
    );
  }
}
