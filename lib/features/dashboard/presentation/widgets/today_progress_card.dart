import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/shared/widgets/linear_progress_bar.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// Dashboard "今日进度" block — a live completion bar.
class TodayProgressCard extends StatelessWidget {
  const TodayProgressCard({super.key, required this.progress});

  /// Completion ratio in `[0, 1]`.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int percent = (progress.clamp(0.0, 1.0) * 100).round();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppStrings.dashboardTodayProgress,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                '$percent%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LinearProgressBar(value: progress),
        ],
      ),
    );
  }
}
