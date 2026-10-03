import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/listening_cue.dart';

/// One spoken line inside a session.
///
/// The transcript is optional: during the blind-listening and dictation steps
/// it stays hidden (`showText == false`) so the learner actually listens;
/// the review steps show it together with the translation and the phonetic
/// traps. A dictation comparison block appears when [dictation] is supplied.
class CueTile extends StatelessWidget {
  const CueTile({
    super.key,
    required this.cue,
    required this.index,
    required this.total,
    this.showText = true,
    this.showTranslation = false,
    this.dictation,
    this.bookmarked = false,
    this.active = false,
    this.onPlay,
    this.onToggleBookmark,
  });

  /// The line to render.
  final ListeningCue cue;

  /// 0-based position inside the section.
  final int index;

  /// Number of cues in the section.
  final int total;

  /// Whether the transcript is visible.
  final bool showText;

  /// Whether the Chinese translation is visible.
  final bool showTranslation;

  /// The learner's dictation for this line, or `null` when not applicable.
  final String? dictation;

  /// Whether this line is in the sentence book.
  final bool bookmarked;

  /// Whether this line is the current one.
  final bool active;

  /// Called when the play button is tapped; `null` disables playback.
  final VoidCallback? onPlay;

  /// Called when the bookmark button is tapped; `null` hides it.
  final VoidCallback? onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: active
                ? theme.colorScheme.secondary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '${index + 1} / $total',
                  style: theme.textTheme.caption.copyWith(
                    color: context.palette.muted,
                  ),
                ),
                if (cue.hasSpeaker) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Text(cue.speaker!, style: theme.textTheme.caption),
                  ),
                ],
                const Spacer(),
                if (onPlay != null)
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    tooltip: AppStrings.listeningPlaySentence,
                    onPressed: onPlay,
                  ),
                if (onToggleBookmark != null)
                  IconButton(
                    icon: Icon(
                      bookmarked ? Icons.bookmark : Icons.bookmark_border,
                    ),
                    tooltip: bookmarked
                        ? AppStrings.listeningInSentenceBook
                        : AppStrings.listeningAddToSentenceBook,
                    onPressed: onToggleBookmark,
                  ),
              ],
            ),
            if (showText) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(cue.text, style: theme.textTheme.bodyLarge),
              if (showTranslation &&
                  cue.translation != null &&
                  cue.translation!.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  cue.translation!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.palette.muted,
                  ),
                ),
              ],
              if (cue.phoneticNotes.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.listeningPhoneticTraps,
                  style: theme.textTheme.caption.copyWith(
                    color: context.palette.muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    for (final String note in cue.phoneticNotes)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: AppRadius.smAll,
                        ),
                        child: Text(note, style: theme.textTheme.bodySmall),
                      ),
                  ],
                ),
              ],
            ],
            if (dictation != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppStrings.vocabularyPracticeYourAnswer,
                style: theme.textTheme.caption.copyWith(
                  color: context.palette.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                dictation!.trim().isEmpty ? AppStrings.readingNoAnswer : dictation!,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
