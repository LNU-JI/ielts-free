import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/features/onboarding/application/onboarding_controller.dart';
import 'package:ielts_free/features/onboarding/presentation/widgets/option_selector.dart';

/// Step 1 — target band (6.0 / 6.5 / 7.0 / 7.5 / 8.0+).
class StepTargetBand extends ConsumerWidget {
  const StepTargetBand({super.key});

  /// Bands matching [AppStrings.onboardingStep1Options] one-to-one.
  static const List<double> bands = <double>[6.0, 6.5, 7.0, 7.5, 8.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingState state = ref.watch(onboardingControllerProvider);
    final OnboardingController controller =
        ref.read(onboardingControllerProvider.notifier);

    return OptionSelector<double>(
      options: bands,
      selected: state.targetBand,
      labelOf: (double band) {
        final int index = bands.indexOf(band);
        return index >= 0 && index < AppStrings.onboardingStep1Options.length
            ? AppStrings.onboardingStep1Options[index]
            : band.toString();
      },
      onSelected: controller.selectTargetBand,
    );
  }
}
