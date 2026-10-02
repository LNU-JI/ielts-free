import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/features/dashboard/application/dashboard_controller.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';
import 'package:ielts_free/shared/widgets/skill_bar.dart';

/// Dashboard "我的能力" block — the five dimension bars.
///
/// Values are shown as 0–100 integers and never converted to a Band (PRD Q-4);
/// a short disclaimer makes clear they are training aids, not official scores.
class SkillScoresCard extends StatelessWidget {
  const SkillScoresCard({super.key, required this.data});

  /// The current dashboard snapshot.
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.dashboardSkillScores,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          for (int i = 0; i < SkillType.fiveDimensions.length; i++) ...<Widget>[
            SkillBar(
              label: _labelOf(SkillType.fiveDimensions[i]),
              value: data.scoreOf(SkillType.fiveDimensions[i]),
              trailing: Icon(
                Icons.chevron_right,
                size: 18,
                color: context.palette.muted,
              ),
            ),
            if (i != SkillType.fiveDimensions.length - 1)
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
    );
  }

  String _labelOf(SkillType skill) {
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
