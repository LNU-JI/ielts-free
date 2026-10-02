import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/features/onboarding/application/onboarding_controller.dart';
import 'package:ielts_free/features/onboarding/presentation/widgets/option_selector.dart';

/// Step 2 — days until the exam (30 / 60 / 90 / 180 / 暂未确定).
class StepExamDate extends ConsumerWidget {
  const StepExamDate({super.key});

  /// Day options matching [AppStrings.onboardingStep2Options]; `null` = 暂未确定.
  static const List<int?> dayOptions = <int?>[30, 60, 90, 180, null];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingState state = ref.watch(onboardingControllerProvider);
    final OnboardingController controller =
        ref.read(onboardingControllerProvider.notifier);

    return OptionSelector<int?>(
      options: dayOptions,
      selected: state.examDays,
      labelOf: (int? days) {
        final int index = dayOptions.indexOf(days);
        return index >= 0 && index < AppStrings.onboardingStep2Options.length
            ? AppStrings.onboardingStep2Options[index]
            : (days == null ? AppStrings.notSet : '$days');
      },
      onSelected: controller.selectExamDays,
    );
  }
}
