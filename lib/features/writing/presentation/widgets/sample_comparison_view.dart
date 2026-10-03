import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/writing_sample.dart';
import 'package:ielts_free/features/writing/presentation/widgets/writing_outline_view.dart';
import 'package:ielts_free/shared/widgets/section_header.dart';

/// The offline stand-in for AI feedback: a banded model essay shown after the
/// attempt is saved, with its paragraph outline and inline annotations.
class SampleComparisonView extends StatelessWidget {
  const SampleComparisonView({super.key, required this.samples});

  /// The model essays attached to the task.
  final List<WritingSample> samples;

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final WritingSample sample in samples) _SampleCard(sample: sample),
      ],
    );
  }
}

class _SampleCard extends StatelessWidget {
  const _SampleCard({required this.sample});

  final WritingSample sample;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppStrings.writingSample,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (sample.hasBand) BandChip(band: sample.band!),
            ],
          ),
          if (sample.outline.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const SectionHeader(title: AppStrings.writingOutline),
            WritingOutlineView(outline: sample.outline),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(sample.essay, style: theme.textTheme.bodyLarge),
          if (sample.annotations.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: AppStrings.writingAnnotations),
            for (final WritingAnnotation annotation in sample.annotations)
              _AnnotationTile(annotation: annotation),
          ],
        ],
      ),
    );
  }
}

class _AnnotationTile extends StatelessWidget {
  const _AnnotationTile({required this.annotation});

  final WritingAnnotation annotation;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: theme.colorScheme.secondary, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '“${annotation.sentence}”',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              annotation.comment,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.palette.muted,
              ),
            ),
            if (annotation.band != null && annotation.band!.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              BandChip(band: annotation.band!),
            ],
          ],
        ),
      ),
    );
  }
}

/// A small pill showing a band label (e.g. `7.5` / `7+`).
class BandChip extends StatelessWidget {
  const BandChip({super.key, required this.band});

  /// The band label.
  final String band;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        band,
        style: theme.textTheme.caption.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
