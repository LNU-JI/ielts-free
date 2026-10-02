import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/responsive.dart';
import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/features/dashboard/application/dashboard_controller.dart';
import 'package:ielts_free/features/dashboard/presentation/widgets/skill_scores_card.dart';
import 'package:ielts_free/features/dashboard/presentation/widgets/streak_card.dart';
import 'package:ielts_free/features/dashboard/presentation/widgets/target_countdown_card.dart';
import 'package:ielts_free/features/dashboard/presentation/widgets/today_progress_card.dart';
import 'package:ielts_free/features/dashboard/presentation/widgets/today_tasks_card.dart';
import 'package:ielts_free/shared/widgets/adaptive_layout.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';

/// Dashboard ("what should I study today?").
///
/// Hosted by both the mobile (`/home`) and desktop (`/dashboard`) shells. It
/// aggregates the goal, today's tasks, the five-dimension ability and the streak
/// (PRD §4.2). Data is read lazily; nothing is scanned in full.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DashboardData> async = ref.watch(dashboardControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.dashboardTitle),
        // Settings lives in the desktop shell, so only offer the shortcut there
        // (mobile reaches it through the "我的" tab).
        actions: <Widget>[
          if (AppBreakpoints.isDesktop(context))
            IconButton(
              tooltip: AppStrings.settingsTitle,
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.go(AppRoutes.settings),
            ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace stackTrace) => ErrorView(
          title: AppStrings.dashboardErrorTitle,
          onRetry: () => ref.invalidate(dashboardControllerProvider),
        ),
        data: (DashboardData data) => _DashboardBody(data: data),
      ),
    );
  }
}

/// The scrollable dashboard content.
class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> generate() async {
      try {
        await ref.read(dashboardControllerProvider.notifier).generateTodayPlan();
      } on Object {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.settingsSaveFailed)),
          );
        }
      }
    }

    final Widget header = TargetCountdownCard(data: data);
    final Widget progress = TodayProgressCard(progress: data.todayProgress);
    final Widget tasks = TodayTasksCard(
      tasks: data.todayTasks,
      onGenerate: generate,
    );
    final Widget skills = SkillScoresCard(data: data);
    final Widget streak = StreakCard(
      streak: data.streak,
      todayMinutes: data.todayMinutes,
    );

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dashboardControllerProvider),
      child: AdaptiveLayout(
        mobile: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            header,
            const SizedBox(height: AppSpacing.lg),
            progress,
            const SizedBox(height: AppSpacing.lg),
            tasks,
            const SizedBox(height: AppSpacing.lg),
            skills,
            const SizedBox(height: AppSpacing.lg),
            streak,
          ],
        ),
        desktopSide: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            header,
            const SizedBox(height: AppSpacing.lg),
            progress,
            const SizedBox(height: AppSpacing.lg),
            tasks,
          ],
        ),
        desktopMain: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            skills,
            const SizedBox(height: AppSpacing.lg),
            streak,
          ],
        ),
      ),
    );
  }
}
