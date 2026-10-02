import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/features/onboarding/application/onboarding_controller.dart';

/// Step 5 — the 15-item initial ability self-assessment (3 × 5 dimensions).
///
/// V0.1 has no Listening / Writing / Speaking item bank, so the whole test is a
/// self-rating; the resulting scores are labelled「估算」(ARCHITECTURE R7,
/// PRD Q-2).
class StepInitialTest extends ConsumerWidget {
  const StepInitialTest({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final OnboardingState state = ref.watch(onboardingControllerProvider);
    final OnboardingController controller =
        ref.read(onboardingControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.onboardingStep5Description,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: AppRadius.smAll,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.info_outline,
                size: 18,
                color: context.palette.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppStrings.onboardingEstimatedNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.palette.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (int i = 0; i < OnboardingState.testLength; i++) ...<Widget>[
          _TestItem(
            index: i,
            question: i < AppStrings.onboardingTestQuestions.length
                ? AppStrings.onboardingTestQuestions[i]
                : '',
            selected: state.answerAt(i),
            onSelected: (int value) => controller.setTestAnswer(i, value),
          ),
          if (i != OnboardingState.testLength - 1)
            const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

/// One self-assessment statement with its three-point rating.
class _TestItem extends StatelessWidget {
  const _TestItem({
    required this.index,
    required this.question,
    required this.selected,
    required this.onSelected,
  });

  final int index;
  final String question;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${index + 1}. $question',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (int value = 0;
                value < AppStrings.onboardingTestOptions.length;
                value++)
              ChoiceChip(
                label: Text(AppStrings.onboardingTestOptions[value]),
                selected: selected == value,
                onSelected: (_) => onSelected(value),
                labelStyle: theme.textTheme.bodySmall,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.smAll,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
