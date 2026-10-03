import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/listening_cue.dart';
import 'package:ielts_free/core/models/listening_question.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// The per-question explanation shown after grading.
///
/// Renders the correct answer, the learner's answer (when wrong), the
/// **evidence sentence** located by `evidenceCueId`, the explanation and the
/// distractor analysis. Every item degrades gracefully when the content omits
/// it.
class ListeningExplanationView extends StatelessWidget {
  const ListeningExplanationView({
    super.key,
    required this.question,
    required this.isCorrect,
    required this.userAnswer,
    this.evidenceCue,
  });

  /// The graded question.
  final ListeningQuestion question;

  /// Whether the answer was correct.
  final bool isCorrect;

  /// The learner's answer.
  final String userAnswer;

  /// The cue that carries the answer, resolved from `evidenceCueId`.
  final ListeningCue? evidenceCue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color =
        isCorrect ? context.palette.success : theme.colorScheme.error;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                AppStrings.readingExplanationTitle,
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              Icon(
                isCorrect ? Icons.check_circle_outline : Icons.cancel_outlined,
                size: 18,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Line(
            label: AppStrings.vocabularyPracticeCorrectAnswer,
            value: question.answer,
          ),
          if (!isCorrect)
            _Line(
              label: AppStrings.vocabularyPracticeYourAnswer,
              value: userAnswer.trim().isEmpty
                  ? AppStrings.readingNoAnswer
                  : userAnswer,
            ),
          if (evidenceCue != null)
            _Line(
              label: AppStrings.listeningEvidence,
              value: evidenceCue!.translation == null ||
                      evidenceCue!.translation!.isEmpty
                  ? evidenceCue!.text
                  : '${evidenceCue!.text}\n${evidenceCue!.translation}',
            ),
          _Line(
            label: AppStrings.readingExplanationTitle,
            value: question.explanation,
          ),
          _Distractors(distractors: question.distractors),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final String? text = value;
    if (text == null || text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.caption.copyWith(color: context.palette.muted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _Distractors extends StatelessWidget {
  const _Distractors({required this.distractors});

  final List<ListeningDistractor> distractors;

  @override
  Widget build(BuildContext context) {
    if (distractors.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.listeningDistractors,
          style: theme.textTheme.caption.copyWith(color: context.palette.muted),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final ListeningDistractor distractor in distractors)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.close,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(distractor.option, style: theme.textTheme.bodyMedium),
                      Text(
                        distractor.reason,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
