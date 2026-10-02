import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';

/// The post-submit feedback block (PRD §4.4 「提交后 ✅ 正确 analyze」).
///
/// Shows a correct / incorrect banner, the correct answer, and — when it is a
/// wrong answer — the user's own answer for comparison.
class AnswerFeedback extends StatelessWidget {
  const AnswerFeedback({
    super.key,
    required this.isCorrect,
    required this.correctAnswer,
    this.userAnswer,
    this.extra,
  });

  /// Whether the answer was correct.
  final bool isCorrect;

  /// The canonical correct answer.
  final String correctAnswer;

  /// The answer the user gave, shown only when incorrect.
  final String? userAnswer;

  /// Optional extra content (e.g. a synonym note).
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color =
        isCorrect ? context.palette.success : theme.colorScheme.error;
    final IconData icon = isCorrect ? Icons.check_circle_outline : Icons.cancel_outlined;
    final String label =
        isCorrect ? AppStrings.vocabularyPracticeCorrect : AppStrings.vocabularyPracticeWrong;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _Line(
            label: AppStrings.vocabularyPracticeCorrectAnswer,
            value: correctAnswer,
          ),
          if (!isCorrect && userAnswer != null && userAnswer!.trim().isNotEmpty)
            _Line(
              label: AppStrings.vocabularyPracticeYourAnswer,
              value: userAnswer!,
            ),
          if (extra != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            extra!,
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.caption.copyWith(color: context.palette.muted),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
