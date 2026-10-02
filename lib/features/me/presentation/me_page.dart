import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/features/dashboard/application/dashboard_controller.dart';
import 'package:ielts_free/shared/widgets/adaptive_layout.dart';
import 'package:ielts_free/shared/widgets/hub_tile.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';
import 'package:ielts_free/shared/widgets/skill_bar.dart';
import 'package:ielts_free/shared/widgets/stat_tile.dart';

/// Mobile "我的" tab (mobile shell route `/me`).
///
/// Shows a compact profile summary (goal, streak, ability) and shortcuts to the
/// plan, mistakes, settings and about screens.
class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final DashboardData? data =
        ref.watch(dashboardControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navMe)),
      body: ContentContainer(
        maxWidth: 720,
        child: ListView(
          children: <Widget>[
            Text(
              AppStrings.meProfileSummary,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: StatTile(
                      label: AppStrings.settingsTargetBand,
                      value: (data?.targetBand ?? 0).toStringAsFixed(1),
                      icon: Icons.flag_outlined,
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: AppStrings.dashboardStreak,
                      value: '${data?.streak ?? 0}',
                      unit: AppStrings.dashboardStreakDaysSuffix,
                      icon: Icons.local_fire_department_outlined,
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: AppStrings.dashboardTodayMinutes,
                      value: '${data?.todayMinutes ?? 0}',
                      unit: AppStrings.dashboardMinutesUnit,
                      icon: Icons.timer_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppStrings.dashboardSkillScores,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final SkillType skill in SkillType.fiveDimensions) ...<Widget>[
                    SkillBar(
                      label: _skillLabel(skill),
                      value: data?.scoreOf(skill) ?? 0,
                    ),
                    if (skill != SkillType.fiveDimensions.last)
                      const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppStrings.dashboardSkillDisclaimer,
                    style: theme.textTheme.caption.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            HubTile(
              icon: Icons.event_note_outlined,
              title: AppStrings.meStudyPlan,
              onTap: () => context.go(AppRoutes.studyPlan),
            ),
            const SizedBox(height: AppSpacing.md),
            HubTile(
              icon: Icons.error_outline,
              title: AppStrings.meMistakes,
              onTap: () => context.go(AppRoutes.mistakes),
            ),
            const SizedBox(height: AppSpacing.md),
            const HubTile(
              icon: Icons.insights_outlined,
              title: AppStrings.meStatistics,
              comingSoon: true,
            ),
            const SizedBox(height: AppSpacing.md),
            HubTile(
              icon: Icons.settings_outlined,
              title: AppStrings.meSettings,
              onTap: () => context.go(AppRoutes.settings),
            ),
            const SizedBox(height: AppSpacing.md),
            HubTile(
              icon: Icons.info_outline,
              title: AppStrings.meAbout,
              onTap: () => context.go(AppRoutes.about),
            ),
          ],
        ),
      ),
    );
  }

  String _skillLabel(SkillType skill) {
    switch (skill) {
      case SkillType.vocabulary:
        return AppStrings.dashboardSkillVocabulary;
      case SkillType.reading:
        return AppStrings.dashboardSkillReading;
      case SkillType.listening:
        return AppStrings.dashboardSkillListening;
      case SkillType.writing:
        return AppStrings.dashboardSkillWriting;
      case SkillType.speaking:
        return AppStrings.dashboardSkillSpeaking;
      default:
        return skill.wire;
    }
  }
}
