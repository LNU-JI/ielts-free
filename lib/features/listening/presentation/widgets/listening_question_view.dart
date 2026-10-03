import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/listening_question.dart';
import 'package:ielts_free/core/utils/text_utils.dart';

/// Renders one listening question and, after grading, its result marker.
///
/// Choice-style questions (multiple choice / matching / map) become option
/// tiles; form / sentence completion questions become a text field. The view is
/// read-only once grading has run.
class ListeningQuestionView extends StatelessWidget {
  const ListeningQuestionView({
    super.key,
    required this.question,
    required this.number,
    required this.value,
    required this.onChanged,
    this.textController,
    this.readOnly = false,
    this.result,
  });

  /// The question to render.
  final ListeningQuestion question;

  /// 1-based question number.
  final int number;

  /// The current answer.
  final String value;

  /// Called when the answer changes.
  final ValueChanged<String> onChanged;

  /// Controller backing the completion text field.
  final TextEditingController? textController;

  /// Whether the question is locked (after grading).
  final bool readOnly;

  /// The grading result, when known.
  final bool? result;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$number.',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(question.prompt, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    question.type.label,
                    style: theme.textTheme.caption.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _answerArea(context),
        if (result != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Icon(
                result! ? Icons.check_circle_outline : Icons.cancel_outlined,
                size: 18,
                color: result!
                    ? context.palette.success
                    : theme.colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                result!
                    ? AppStrings.vocabularyPracticeCorrect
                    : AppStrings.vocabularyPracticeWrong,
                style: theme.textTheme.caption.copyWith(
                  color: result!
                      ? context.palette.success
                      : theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _answerArea(BuildContext context) {
    if (question.type.isChoice && question.options.isNotEmpty) {
      return _choices(context);
    }
    return TextField(
      controller: textController,
      enabled: !readOnly,
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
      decoration: const InputDecoration(
        hintText: AppStrings.vocabularyPracticeAnswerHint,
      ),
    );
  }

  Widget _choices(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final ListeningOption option in question.options)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ChoiceTile(
              label: _optionLabel(option),
              selected: _optionSelected(option),
              correct: _optionCorrect(option),
              readOnly: readOnly,
              onTap: () => onChanged(_optionValue(option)),
            ),
          ),
      ],
    );
  }

  String _optionLabel(ListeningOption option) =>
      option.label.isEmpty ? option.content : '${option.label}. ${option.content}';

  String _optionValue(ListeningOption option) =>
      option.label.isEmpty ? option.content : option.label;

  bool _optionSelected(ListeningOption option) {
    final String norm = TextUtils.normalize(value);
    if (norm.isEmpty) {
      return false;
    }
    return norm == TextUtils.normalize(option.label) ||
        norm == TextUtils.normalize(option.content);
  }

  bool _optionCorrect(ListeningOption option) {
    for (final String accepted in question.acceptedAnswers) {
      final String norm = TextUtils.normalize(accepted);
      if (norm == TextUtils.normalize(option.label) ||
          norm == TextUtils.normalize(option.content)) {
        return true;
      }
    }
    return false;
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.correct,
    required this.readOnly,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool correct;
  final bool readOnly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    Color borderColor = theme.colorScheme.outlineVariant;
    Color? background;
    IconData? icon;

    if (readOnly) {
      if (correct) {
        borderColor = context.palette.success;
        icon = Icons.check_circle_outline;
      } else if (selected) {
        borderColor = theme.colorScheme.error;
        icon = Icons.cancel_outlined;
      }
    } else if (selected) {
      borderColor = theme.colorScheme.secondary;
      background = theme.colorScheme.secondaryContainer;
    }

    return InkWell(
      borderRadius: AppRadius.mdAll,
      onTap: readOnly ? null : onTap,
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
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            if (icon != null)
              Icon(
                icon,
                size: 18,
                color: correct
                    ? context.palette.success
                    : theme.colorScheme.error,
              ),
          ],
        ),
      ),
    );
  }
}
