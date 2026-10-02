import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/features/study_plan/application/study_plan_controller.dart';
import 'package:ielts_free/features/study_plan/presentation/widgets/plan_selector.dart';
import 'package:ielts_free/features/study_plan/presentation/widgets/weekly_schedule.dart';
import 'package:ielts_free/shared/widgets/adaptive_layout.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';
import 'package:ielts_free/shared/widgets/primary_button.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// Study Plan page (desktop shell route `/study-plan`, PRD §4.7).
class StudyPlanPage extends ConsumerWidget {
  const StudyPlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<StudyPlanState> async =
        ref.watch(studyPlanControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.studyPlanTitle)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace stackTrace) => ErrorView(
          title: AppStrings.studyPlanErrorTitle,
          onRetry: () => ref.invalidate(studyPlanControllerProvider),
        ),
        data: (StudyPlanState state) => _StudyPlanBody(state: state),
      ),
    );
  }
}

/// The scrollable study-plan content.
class _StudyPlanBody extends ConsumerWidget {
  const _StudyPlanBody({required this.state});

  final StudyPlanState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final StudyPlanController controller =
        ref.read(studyPlanControllerProvider.notifier);

    final String phaseLabel =
        AppStrings.studyPlanPhaseLabel(state.phase.wire);
    final String phaseSummary = AppStrings.studyPlanPhaseSummary(
      phaseLabel,
      state.daysRemaining,
    );

    return ContentContainer(
      maxWidth: 760,
      child: ListView(
        children: <Widget>[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.studyPlanPeriod,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                PlanSelector(
                  period: state.period,
                  customDays: state.customDays,
                  enabled: !state.busy,
                  onSelected: (period, customDays) =>
                      controller.setPeriod(period, customDays: customDays),
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
                  AppStrings.studyPlanCurrentPhase,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(phaseSummary, style: theme.textTheme.bodyLarge),
                if (state.daysRemaining == null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppStrings.studyPlanNoExamDate,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          WeeklySchedule(days: state.weekly),
          const SizedBox(height: AppSpacing.lg),
          if (state.error != null) ...<Widget>[
            Text(
              state.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          PrimaryButton(
            label: AppStrings.studyPlanRegenerate,
            icon: Icons.refresh,
            isLoading: state.busy,
            expand: true,
            onPressed: controller.regenerateToday,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
