import 'package:flutter/material.dart';

import 'package:ielts_free/app/theme.dart';

/// A compact grid of question numbers (PRD §4.5 「保留题号、进度」).
///
/// Each chip is numbered; its colour reflects the state — answered (secondary),
/// correct (success), wrong (error) or unanswered (neutral). Tapping a chip jumps
/// to that question.
class QuestionNavigator extends StatelessWidget {
  const QuestionNavigator({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.answered,
    this.results = const <int, bool>{},
    required this.onSelect,
  });

  /// Number of questions.
  final int count;

  /// The question currently shown (0-based).
  final int currentIndex;

  /// Indices (0-based) that have an answer.
  final Set<int> answered;

  /// Grading results keyed by 0-based index (after submit).
  final Map<int, bool> results;

  /// Called when a chip is tapped.
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          _NavChip(
            number: i + 1,
            current: i == currentIndex,
            isAnswered: answered.contains(i),
            result: results[i],
            onTap: () => onSelect(i),
            theme: theme,
          ),
      ],
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({
    required this.number,
    required this.current,
    required this.isAnswered,
    required this.result,
    required this.onTap,
    required this.theme,
  });

  final int number;
  final bool current;
  final bool isAnswered;
  final bool? result;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    Color border = theme.colorScheme.outlineVariant;
    Color? fill;
    Color textColor = theme.colorScheme.onSurface;

    if (result == true) {
      border = context.palette.success;
      fill = theme.colorScheme.surfaceContainerHighest;
      textColor = context.palette.success;
    } else if (result == false) {
      border = theme.colorScheme.error;
      fill = theme.colorScheme.surfaceContainerHighest;
      textColor = theme.colorScheme.error;
    } else if (isAnswered) {
      border = theme.colorScheme.secondary;
      fill = theme.colorScheme.secondaryContainer;
    }
    if (current) {
      border = theme.colorScheme.secondary;
    }

    return InkWell(
      borderRadius: AppRadius.smAll,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: AppRadius.smAll,
          border: Border.all(
            color: border,
            width: current ? 2 : 1,
          ),
        ),
        child: Text(
          '$number',
          style: theme.textTheme.label.copyWith(color: textColor),
        ),
      ),
    );
  }
}
