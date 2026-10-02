import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/vocabulary.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// The full vocabulary card used on the detail page (PRD §4.3 / BRIEF §14).
///
/// Every field of the PRD layout is rendered, but **missing fields degrade
/// gracefully**: a null / empty value is simply omitted instead of throwing or
/// showing a placeholder glyph (FR-030). This lets the seed content grow richer
/// over time without breaking the UI.
class WordCard extends StatelessWidget {
  const WordCard({
    super.key,
    required this.vocabulary,
    this.topics = const <String>[],
    this.memoryLevel,
    this.isMastered = false,
  });

  /// The word to display.
  final Vocabulary vocabulary;

  /// Topic tags attached to the word.
  final List<String> topics;

  /// The user's current memory level, when known.
  final int? memoryLevel;

  /// Whether the word has reached the mastered level.
  final bool isMastered;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _header(context, theme),
          const SizedBox(height: AppSpacing.lg),
          _Field(label: AppStrings.vocabularyMeaningCn, value: vocabulary.meaningCn),
          _Field(label: AppStrings.vocabularyMeaningEn, value: vocabulary.meaningEn),
          _ListField(
            label: AppStrings.vocabularyCollocations,
            values: vocabulary.collocations,
          ),
          _Field(label: AppStrings.vocabularyWritingUsage, value: vocabulary.writingUsage),
          _Field(
            label: AppStrings.vocabularySpeakingUsage,
            value: vocabulary.speakingUsage,
          ),
          _ExamplesField(examples: vocabulary.examples),
          _ListField(label: AppStrings.vocabularySynonyms, values: vocabulary.synonyms),
          _ListField(label: AppStrings.vocabularyAntonyms, values: vocabulary.antonyms),
          _ListField(
            label: AppStrings.vocabularyCommonMistakes,
            values: vocabulary.commonMistakes,
          ),
          _ListField(
            label: AppStrings.vocabularyRelatedWords,
            values: vocabulary.relatedWords,
          ),
          _TopicsField(topics: topics),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Flexible(
              child: Text(
                vocabulary.word,
                style: theme.textTheme.displayLarge,
              ),
            ),
            if (vocabulary.phonetic != null && vocabulary.phonetic!.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.md),
              Text(
                vocabulary.phonetic!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ],
            if (vocabulary.partOfSpeech != null &&
                vocabulary.partOfSpeech!.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                vocabulary.partOfSpeech!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.palette.muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            _Chip(text: AppStrings.vocabularyDifficultyLabel(vocabulary.difficulty)),
            if (vocabulary.cefr != null && vocabulary.cefr!.isNotEmpty)
              _Chip(text: vocabulary.cefr!),
            if (vocabulary.ieltsLevel != null && vocabulary.ieltsLevel!.isNotEmpty)
              _Chip(text: vocabulary.ieltsLevel!),
            if (memoryLevel != null)
              _Chip(text: AppStrings.vocabularyLevelLabel(memoryLevel!)),
            if (isMastered)
              _Chip(
                text: AppStrings.vocabularyMastered,
                color: context.palette.success,
              ),
          ],
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, this.value});

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
          Text(text, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _ListField extends StatelessWidget {
  const _ListField({required this.label, required this.values});

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

class _ExamplesField extends StatelessWidget {
  const _ExamplesField({required this.examples});

  final List<VocabularyExample> examples;

  @override
  Widget build(BuildContext context) {
    final List<VocabularyExample> items = examples
        .where((VocabularyExample e) => e.en.trim().isNotEmpty)
        .toList(growable: false);
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
            AppStrings.vocabularyExamples,
            style: theme.textTheme.caption.copyWith(color: context.palette.muted),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final VocabularyExample example in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(example.en, style: theme.textTheme.bodyLarge),
                  if (example.cn != null && example.cn!.trim().isNotEmpty)
                    Text(
                      example.cn!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.palette.muted,
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

class _TopicsField extends StatelessWidget {
  const _TopicsField({required this.topics});

  final List<String> topics;

  @override
  Widget build(BuildContext context) {
    final List<String> items =
        topics.where((String t) => t.trim().isNotEmpty).toList(growable: false);
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.vocabularyTopicLabel,
          style: theme.textTheme.caption.copyWith(color: context.palette.muted),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: items
              .map((String topic) => _Chip(text: topic))
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color effective = color ?? context.palette.muted;
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
        style: theme.textTheme.caption.copyWith(color: effective),
      ),
    );
  }
}
