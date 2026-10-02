import 'package:flutter/material.dart';

import 'package:ielts_free/app/theme.dart';

/// The remaining-time indicator used by the reading page (PRD §4.5 / BRIEF §18).
///
/// Shows `mm:ss` and switches to the warning color in the last minute so the
/// user notices the coming auto-submit (PRD Q-9).
class SessionTimer extends StatelessWidget {
  const SessionTimer({super.key, required this.remainingSeconds});

  /// Seconds left before auto-submit.
  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool urgent = remainingSeconds <= 60;
    final Color color =
        urgent ? context.palette.warning : context.palette.muted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.timer_outlined, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          format(remainingSeconds),
          style: theme.textTheme.label.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
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
