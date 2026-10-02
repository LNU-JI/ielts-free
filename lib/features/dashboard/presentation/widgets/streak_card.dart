import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';
import 'package:ielts_free/shared/widgets/stat_tile.dart';

/// Dashboard "连续学习 / 今日已学" block.
class StreakCard extends StatelessWidget {
  const StreakCard({
    super.key,
    required this.streak,
    required this.todayMinutes,
  });

  /// Current streak in days.
  final int streak;

  /// Minutes studied today.
  final int todayMinutes;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: StatTile(
              label: AppStrings.dashboardStreak,
              value: '$streak',
              unit: AppStrings.dashboardStreakDaysSuffix,
              icon: Icons.local_fire_department_outlined,
            ),
          ),
          Expanded(
            child: StatTile(
              label: AppStrings.dashboardTodayMinutes,
              value: '$todayMinutes',
              unit: AppStrings.dashboardMinutesUnit,
              icon: Icons.timer_outlined,
            ),
          ),
        ],
      ),
    );
  }
}
