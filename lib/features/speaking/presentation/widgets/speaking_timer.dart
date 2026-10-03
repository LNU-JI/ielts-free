import 'package:flutter/material.dart';

import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/shared/widgets/linear_progress_bar.dart';

/// The countdown used by the speaking session.
///
/// Shows the stage label (准备时间 / 作答时间), the remaining `mm:ss` and a
/// progress bar. It turns to the warning color in the last ten seconds so the
/// learner notices the automatic stop.
class SpeakingTimer extends StatelessWidget {
  const SpeakingTimer({
    super.key,
    required this.label,
    required this.remainingSeconds,
    required this.totalSeconds,
  });

  /// Stage label (already localized).
  final String label;

  /// Seconds left in the stage.
  final int remainingSeconds;

  /// Total seconds of the stage.
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool urgent = remainingSeconds <= 10;
    final Color color =
        urgent ? context.palette.warning : theme.colorScheme.secondary;
    final double value =
        totalSeconds <= 0 ? 0 : remainingSeconds / totalSeconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.label.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ),
            Icon(Icons.timer_outlined, size: 16, color: color),
            const SizedBox(width: AppSpacing.xs),
            Text(
              format(remainingSeconds),
              style: theme.textTheme.titleSmall?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        LinearProgressBar(value: value, height: AppSpacing.sm),
      ],
    );
  }

  /// Formats [seconds] as `mm:ss`.
  static String format(int seconds) {
    final int safe = seconds < 0 ? 0 : seconds;
    final int minutes = safe ~/ 60;
    final int secs = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
