import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/reading_question.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// The per-question explanation shown after submission (BRIEF §19).
///
/// Renders the six required items — correctAnswer / evidence / keywords /
/// synonyms / logic / explanation — and, crucially, the **synonym-replacement
/// note** (同义替换说明) which is the single most useful reading takeaway. Every
/// item degrades gracefully when the content omits it.
class ExplanationView extends StatelessWidget {
  const ExplanationView({
    super.key,
    required this.question,
    required this.isCorrect,
    this.userAnswer,
  });

  /// The graded question.
  final ReadingQuestion question;

  /// Whether the user answered correctly.
  final bool isCorrect;

  /// The user's answer, shown for comparison when incorrect.
  final String? userAnswer;

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
              Text(AppStrings.readingExplanationTitle, style: theme.textTheme.titleSmall),
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
            label: AppStrings.readingCorrectAnswerLabel,
            value: question.correctAnswer,
          ),
          if (!isCorrect)
            _Line(
              label: AppStrings.readingYourAnswer,
              value: (userAnswer ?? '').trim().isEmpty
                  ? AppStrings.readingNoAnswer
                  : userAnswer!,
            ),
          _Line(label: AppStrings.readingEvidence, value: question.evidence),
          _ListLine(label: AppStrings.readingKeywords, values: question.keywords),
          _Synonyms(synonyms: question.synonyms),
          _Line(label: AppStrings.readingLogic, value: question.logic),
          _Line(label: AppStrings.readingExplanationTitle, value: question.explanation),
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

class _ListLine extends StatelessWidget {
  const _ListLine({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final List<String> items =
        values.where((String v) => v.trim().isNotEmpty).toList(growable: false);
    if (items.isEmpty) {
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
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: items
                .map(
                  (String value) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Text(value, style: theme.textTheme.bodySmall),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _Synonyms extends StatelessWidget {
  const _Synonyms({required this.synonyms});

  final List<List<String>> synonyms;

  @override
  Widget build(BuildContext context) {
    final List<List<String>> pairs = synonyms
        .where((List<String> p) => p.length >= 2 && p[0].isNotEmpty && p[1].isNotEmpty)
        .toList(growable: false);
    if (pairs.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.readingSynonyms,
            style: theme.textTheme.caption.copyWith(color: context.palette.muted),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final List<String> pair in pairs)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  Flexible(
                    child: Text(pair[0], style: theme.textTheme.bodyMedium),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: context.palette.muted,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      pair[1],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
