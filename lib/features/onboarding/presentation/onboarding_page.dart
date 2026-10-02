import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/features/onboarding/application/onboarding_controller.dart';
import 'package:ielts_free/features/onboarding/presentation/widgets/onboarding_progress.dart';
import 'package:ielts_free/features/onboarding/presentation/widgets/step_daily_minutes.dart';
import 'package:ielts_free/features/onboarding/presentation/widgets/step_exam_date.dart';
import 'package:ielts_free/features/onboarding/presentation/widgets/step_initial_test.dart';
import 'package:ielts_free/features/onboarding/presentation/widgets/step_target_band.dart';
import 'package:ielts_free/features/onboarding/presentation/widgets/step_weakest_skill.dart';
import 'package:ielts_free/shared/widgets/adaptive_layout.dart';
import 'package:ielts_free/shared/widgets/primary_button.dart';

/// Five-step Onboarding container (PRD §4.1).
///
/// Shows the `●○○○○ Step n / 5` indicator, the current step's content and the
/// back / next controls. The whole flow works offline; the final step writes the
/// profile, goal and five initial scores before leaving the route.
class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final OnboardingState state = ref.watch(onboardingControllerProvider);
    final OnboardingController controller =
        ref.read(onboardingControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.onboardingTitle)),
      body: SafeArea(
        child: ContentContainer(
          maxWidth: 640,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              OnboardingProgress(
                current: state.stepIndex + 1,
                total: OnboardingState.totalSteps,
                label: AppStrings.onboardingStepIndicator(
                  state.stepIndex + 1,
                  OnboardingState.totalSteps,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(_titleFor(state.step), style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: SingleChildScrollView(
                  child: _bodyFor(state.step),
                ),
              ),
              if (state.error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  state.error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _Controls(
                state: state,
                onBack: controller.back,
                onNext: controller.next,
                onFinish: controller.finish,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _titleFor(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.targetBand:
        return AppStrings.onboardingStep1Title;
      case OnboardingStep.examDate:
        return AppStrings.onboardingStep2Title;
      case OnboardingStep.dailyMinutes:
        return AppStrings.onboardingStep3Title;
      case OnboardingStep.weakestSkill:
        return AppStrings.onboardingStep4Title;
      case OnboardingStep.initialTest:
        return AppStrings.onboardingStep5Title;
    }
  }

  Widget _bodyFor(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.targetBand:
        return const StepTargetBand();
      case OnboardingStep.examDate:
        return const StepExamDate();
      case OnboardingStep.dailyMinutes:
        return const StepDailyMinutes();
      case OnboardingStep.weakestSkill:
        return const StepWeakestSkill();
      case OnboardingStep.initialTest:
        return const StepInitialTest();
    }
  }
}

/// The back / next / finish control row.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.onBack,
    required this.onNext,
    required this.onFinish,
  });

  final OnboardingState state;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final Future<void> Function() onFinish;

  @override
  Widget build(BuildContext context) {
    final bool isLast = state.isLastStep;

    return Row(
      children: <Widget>[
        if (state.canGoBack)
          SecondaryButton(
            label: AppStrings.previous,
            onPressed: state.submitting ? null : onBack,
          ),
        const Spacer(),
        if (isLast)
          PrimaryButton(
            label: AppStrings.onboardingFinish,
            icon: Icons.check,
            isLoading: state.submitting,
            onPressed: state.canProceed ? onFinish : null,
          )
        else
          PrimaryButton(
            label: AppStrings.next,
            icon: Icons.arrow_forward,
            onPressed: state.canProceed ? onNext : null,
          ),
      ],
    );
  }
}
