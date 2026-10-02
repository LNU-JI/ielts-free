import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/services/grading_service.dart';
import 'package:ielts_free/core/utils/text_utils.dart';
import 'package:ielts_free/features/vocabulary/application/vocab_question_builder.dart';

/// Renders one practice question in the shape its kind requires (PRD §4.4).
///
/// - typed kinds (`word→meaning`, `meaning→word`, `spelling`, `cloze`) show a
///   text field;
/// - choice kinds (四选一 / 同义词 / 搭配) show option cards.
///
/// After submission the view becomes read-only and, for choice questions, marks
/// the correct option and the user's (wrong) pick.
class PracticeQuestionView extends StatelessWidget {
  const PracticeQuestionView({
    super.key,
    required this.item,
    required this.answered,
    this.selected,
    this.textController,
    this.onSelect,
    this.onSubmitted,
    this.submitting = false,
  });

  /// The question to render.
  final VocabPracticeItem item;

  /// Whether the question has already been answered.
  final bool answered;

  /// The currently selected option (choice kinds only).
  final String? selected;

  /// Controller backing the text field (typed kinds only).
  final TextEditingController? textController;

  /// Called when an option is tapped.
  final ValueChanged<String>? onSelect;

  /// Called when a typed answer is submitted from the keyboard.
  final ValueChanged<String>? onSubmitted;

  /// Whether a grade write is in flight.
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: AppRadius.smAll,
              ),
              child: Text(
                AppStrings.vocabularyPracticeKindLabel(item.kindNumber),
                style: theme.textTheme.caption,
              ),
            ),
            Text(
              AppStrings.vocabularyPracticeKindNames[item.kind.index],
              style: theme.textTheme.caption.copyWith(
                color: context.palette.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          AppStrings.vocabularyPracticeQuestion,
          style: theme.textTheme.caption.copyWith(color: context.palette.muted),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(item.prompt, style: theme.textTheme.headline),
        if (item.hint != null && item.hint!.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${AppStrings.vocabularyPracticeHint}：${item.hint!}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.palette.muted,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (item.isChoice) _options(context) else _input(context),
      ],
    );
  }

  Widget _options(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final String option in item.options)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _OptionTile(
              text: option,
              selected: selected == option,
              answered: answered,
              isCorrect: _sameAnswer(option, item.expected),
              onTap: answered || submitting ? null : () => onSelect?.call(option),
            ),
          ),
      ],
    );
  }

  Widget _input(BuildContext context) {
    final String hint = item.kind == VocabQuestionKind.spelling
        ? AppStrings.vocabularyPracticeSpellingHint
        : AppStrings.vocabularyPracticeAnswerHint;
    return TextField(
      controller: textController,
      enabled: !answered && !submitting,
      textInputAction: TextInputAction.done,
      onSubmitted: answered ? null : onSubmitted,
      decoration: InputDecoration(hintText: hint),
    );
  }

  bool _sameAnswer(String a, String b) =>
      TextUtils.normalize(a) == TextUtils.normalize(b);
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.text,
    required this.selected,
    required this.answered,
    required this.isCorrect,
    this.onTap,
  });

  final String text;
  final bool selected;
  final bool answered;
  final bool isCorrect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    Color borderColor = theme.colorScheme.outlineVariant;
    Color? background;
    IconData? trailingIcon;

    if (answered) {
      if (isCorrect) {
        borderColor = context.palette.success;
        trailingIcon = Icons.check_circle_outline;
      } else if (selected) {
        borderColor = theme.colorScheme.error;
        trailingIcon = Icons.cancel_outlined;
      }
    } else if (selected) {
      borderColor = theme.colorScheme.secondary;
      background = theme.colorScheme.secondaryContainer;
    }

    return InkWell(
      borderRadius: AppRadius.mdAll,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(text, style: theme.textTheme.bodyLarge),
            ),
            if (trailingIcon != null)
              Icon(
                trailingIcon,
                size: 20,
                color: isCorrect ? context.palette.success : theme.colorScheme.error,
              ),
          ],
        ),
      ),
    );
  }
}
