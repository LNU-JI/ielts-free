import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/speaking_question.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// The model answer and the high-value phrases for the current question.
///
/// Revealed after the learner has answered, so the answer is their own first.
class SampleAnswerView extends StatelessWidget {
  const SampleAnswerView({super.key, required this.question});

  /// The question whose model answer is shown.
  final SpeakingQuestion question;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? sample = question.sampleAnswer;
    final List<String> phrases = question.keyPhrases;

    if ((sample == null || sample.isEmpty) && phrases.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (sample != null && sample.isNotEmpty)
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.speakingSampleAnswer,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(sample, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        if (phrases.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.speakingKeyPhrases,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final String phrase in phrases)
                      Chip(
                        label: Text(phrase),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
