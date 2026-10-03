import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/features/listening/application/listening_controller.dart';

/// The six-step progress bar at the top of an intensive-listening session.
///
/// Every step is directly selectable so the learner can jump back to the
/// transcript or the error-classification step at any time.
class ListeningStepBar extends StatelessWidget {
  const ListeningStepBar({
    super.key,
    required this.current,
    required this.onSelect,
  });

  /// The step currently shown.
  final ListeningStep current;

  /// Called when a step chip is tapped.
  final ValueChanged<ListeningStep> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.onboardingStepIndicator(
            current.position,
            ListeningStep.values.length,
          ),
          style: theme.textTheme.caption.copyWith(color: context.palette.muted),
        ),
        const SizedBox(height: AppSpacing.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final ListeningStep step in ListeningStep.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(step.label),
                    selected: step == current,
                    onSelected: (_) => onSelect(step),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
