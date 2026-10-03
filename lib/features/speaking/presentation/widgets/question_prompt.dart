import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/speaking_question.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// The examiner's prompt for the current speaking question.
///
/// Shows the English question, its optional Chinese gloss and — for Part 3, and
/// any question that carries them — the follow-up probes, which stay collapsed
/// until the learner asks for them.
class QuestionPrompt extends StatelessWidget {
  const QuestionPrompt({
    super.key,
    required this.question,
    required this.number,
    required this.total,
  });

  /// The question to display.
  final SpeakingQuestion question;

  /// 1-based position of the question.
  final int number;

  /// Number of questions in the topic.
  final int total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? cn = question.questionCn;
    final List<String> followUps = question.followUps;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.vocabularyPracticeProgress(number, total),
            style: theme.textTheme.caption.copyWith(
              color: context.palette.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(question.question, style: theme.textTheme.titleMedium),
          if (cn != null && cn.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              cn,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.palette.muted,
              ),
            ),
          ],
          if (followUps.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(
                  bottom: AppSpacing.sm,
                ),
                title: Text(
                  AppStrings.speakingFollowUps,
                  style: theme.textTheme.label.copyWith(
                    color: context.palette.muted,
                  ),
                ),
                children: <Widget>[
                  for (final String followUp in followUps)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('·', style: theme.textTheme.bodyMedium),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              followUp,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
