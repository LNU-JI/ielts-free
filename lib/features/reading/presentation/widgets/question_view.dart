import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/enums/question_type.dart';
import 'package:ielts_free/core/models/reading_option.dart';
import 'package:ielts_free/core/models/reading_question.dart';
import 'package:ielts_free/core/utils/text_utils.dart';

/// Renders one reading question in the shape its type requires (PRD §4.5).
///
/// Supports every question type the content schema defines: T/F/NG, Y/N/NG,
/// multiple choice, matching headings / information, and the four gap-fill
/// completion types. After submission the view is read-only and highlights the
/// correct option / value.
class QuestionView extends StatelessWidget {
  const QuestionView({
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
  final ReadingQuestion question;

  /// 1-based question number.
  final int number;

  /// The current answer.
  final String value;

  /// Called when the answer changes.
  final ValueChanged<String> onChanged;

  /// Controller backing the gap-fill text field.
  final TextEditingController? textController;

  /// Whether the question is locked (after submit).
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
              child: Text(question.prompt, style: theme.textTheme.bodyLarge),
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
    final QuestionType type = question.questionType;
    if (type.isTrueFalseNotGiven) {
      return _tfng(context);
    }
    if (type.isChoice && question.options.isNotEmpty) {
      return _choices(context);
    }
    return _completion(context);
  }

  Widget _tfng(BuildContext context) {
    final List<String> labels = _tfngLabels(question.questionType);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: labels
          .map(
            (String label) => _ChoiceChipTile(
              label: label,
              selected: _matches(value, label),
              correct: _matches(question.correctAnswer, label),
              readOnly: readOnly,
              onTap: () => onChanged(label),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _choices(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final ReadingOption option in question.options)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ChoiceChipTile(
              label: _optionLabel(option),
              selected: _matches(value, option.label ?? option.content),
              correct: _matches(
                question.correctAnswer,
                option.label ?? option.content,
              ),
              readOnly: readOnly,
              onTap: () => onChanged(option.label ?? option.content),
            ),
          ),
      ],
    );
  }

  Widget _completion(BuildContext context) {
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

  List<String> _tfngLabels(QuestionType type) => type == QuestionType.ynng
      ? const <String>['Yes', 'No', 'Not Given']
      : const <String>['True', 'False', 'Not Given'];

  String _optionLabel(ReadingOption option) {
    final String? label = option.label;
    if (label != null && label.isNotEmpty) {
      return '$label. ${option.content}';
    }
    return option.content;
  }

  bool _matches(String a, String b) {
    if (a.trim().isEmpty || b.trim().isEmpty) {
      return false;
    }
    final QuestionType type = question.questionType;
    if (type.isTrueFalseNotGiven) {
      return TextUtils.canonicalTrueFalse(a) == TextUtils.canonicalTrueFalse(b);
    }
    if (type.isChoice) {
      // Compare on the trailing text (ignore a leading `A. ` label prefix).
      return TextUtils.normalize(_stripLabel(a)) ==
          TextUtils.normalize(_stripLabel(b));
    }
    return TextUtils.answersMatchLoose(a, b);
  }

  String _stripLabel(String value) {
    final int dot = value.indexOf('. ');
    if (dot > 0 && dot <= 2) {
      return value.substring(dot + 2);
    }
    return value;
  }
}

class _ChoiceChipTile extends StatelessWidget {
  const _ChoiceChipTile({
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
                color: correct ? context.palette.success : theme.colorScheme.error,
              ),
          ],
        ),
      ),
    );
  }
}
