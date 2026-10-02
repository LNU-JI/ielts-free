import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/shared/widgets/linear_progress_bar.dart';

/// The progress + timer header used by the vocabulary practice page (PRD §4.4).
///
/// Shows the running question counter, a progress bar and the elapsed time.
class ReviewQueueHeader extends StatelessWidget {
  const ReviewQueueHeader({
    super.key,
    required this.current,
    required this.total,
    required this.elapsedSeconds,
    this.title,
  });

  /// 1-based index of the current question.
  final int current;

  /// Total number of questions.
  final int total;

  /// Seconds elapsed since the run began.
  final int elapsedSeconds;

  /// Optional title shown on the left.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double ratio = total == 0 ? 0 : (current / total).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (title != null) ...<Widget>[
              Expanded(
                child: Text(
                  title!,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Spacer(),
            Text(
              AppStrings.vocabularyPracticeProgress(current, total),
              style: theme.textTheme.label,
            ),
            const SizedBox(width: AppSpacing.md),
            Icon(Icons.timer_outlined, size: 16, color: context.palette.muted),
            const SizedBox(width: AppSpacing.xs),
            Text(
              formatClock(elapsedSeconds),
              style: theme.textTheme.label.copyWith(color: context.palette.muted),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        LinearProgressBar(value: ratio),
      ],
    );
  }

  /// Formats [seconds] as `mm:ss` (hours are folded into minutes).
  static String formatClock(int seconds) {
    final int safe = seconds < 0 ? 0 : seconds;
    final int minutes = safe ~/ 60;
    final int secs = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
