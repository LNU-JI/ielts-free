import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/core/models/enums/skill_type.dart';
import 'package:ielts_free/features/onboarding/application/onboarding_controller.dart';
import 'package:ielts_free/features/onboarding/presentation/widgets/option_selector.dart';

/// Step 4 — self-declared weakest skill.
///
/// `null` represents 不知道. The choice seeds the conservative initial score of
/// the three dimensions that have no V0.1 item bank (ARCHITECTURE R7).
class StepWeakestSkill extends ConsumerWidget {
  const StepWeakestSkill({super.key});

  /// Skill options matching [AppStrings.onboardingStep4Options]; `null` = 不知道.
  static const List<SkillType?> skillOptions = <SkillType?>[
    SkillType.listening,
    SkillType.reading,
    SkillType.writing,
    SkillType.speaking,
    SkillType.vocabulary,
    null,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingState state = ref.watch(onboardingControllerProvider);
    final OnboardingController controller =
        ref.read(onboardingControllerProvider.notifier);

    return OptionSelector<SkillType?>(
      options: skillOptions,
      selected: state.weakestSkill,
      labelOf: (SkillType? skill) {
        final int index = skillOptions.indexOf(skill);
        return index >= 0 && index < AppStrings.onboardingStep4Options.length
            ? AppStrings.onboardingStep4Options[index]
            : AppStrings.notSet;
      },
      onSelected: controller.selectWeakestSkill,
    );
  }
}
