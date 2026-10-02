import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/features/onboarding/application/onboarding_controller.dart';
import 'package:ielts_free/features/onboarding/presentation/widgets/option_selector.dart';

/// Step 3 — daily study minutes (30 / 60 / 90 / 120).
class StepDailyMinutes extends ConsumerWidget {
  const StepDailyMinutes({super.key});

  /// Minute options matching [AppStrings.onboardingStep3Options].
  static const List<int> minuteOptions = <int>[30, 60, 90, 120];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingState state = ref.watch(onboardingControllerProvider);
    final OnboardingController controller =
        ref.read(onboardingControllerProvider.notifier);

    return OptionSelector<int>(
      options: minuteOptions,
      selected: state.dailyMinutes,
      labelOf: (int minutes) {
        final int index = minuteOptions.indexOf(minutes);
        return index >= 0 && index < AppStrings.onboardingStep3Options.length
            ? AppStrings.onboardingStep3Options[index]
            : '$minutes ${AppStrings.minutesWord}';
      },
      onSelected: controller.selectDailyMinutes,
    );
  }
}
