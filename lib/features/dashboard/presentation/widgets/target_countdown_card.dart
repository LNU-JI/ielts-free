import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/features/dashboard/application/dashboard_controller.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';
import 'package:ielts_free/shared/widgets/stat_tile.dart';

/// Dashboard header: target band + exam countdown.
///
/// Tapping it opens Settings so the goal can be edited (PRD §4.2).
class TargetCountdownCard extends StatelessWidget {
  const TargetCountdownCard({super.key, required this.data});

  /// The current dashboard snapshot.
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final String countdownValue = data.daysRemaining == null
        ? AppStrings.dashboardNoExamDate
        : '${data.daysRemaining}';

    return SectionCard(
      onTap: () => context.go(AppRoutes.settings),
      child: Row(
        children: <Widget>[
          Expanded(
            child: StatTile(
              label: AppStrings.dashboardTarget,
              value: data.targetBand.toStringAsFixed(1),
              icon: Icons.flag_outlined,
            ),
          ),
          Expanded(
            child: StatTile(
              label: AppStrings.dashboardCountdown,
              value: countdownValue,
              unit: data.daysRemaining == null
                  ? null
                  : AppStrings.dashboardDaysSuffix,
              icon: Icons.event_outlined,
            ),
          ),
          Icon(
            Icons.edit_outlined,
            size: 18,
            color: context.palette.muted,
          ),
        ],
      ),
    );
  }
}
