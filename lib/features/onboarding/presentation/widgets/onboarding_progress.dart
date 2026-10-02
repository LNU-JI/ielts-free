import 'package:flutter/material.dart';

import 'package:ielts_free/app/theme.dart';

/// The `●○○○○  Step n / 5` indicator shown at the top of Onboarding.
class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({
    super.key,
    required this.current,
    required this.total,
    required this.label,
  });

  /// 1-based index of the current step.
  final int current;

  /// Total number of steps.
  final int total;

  /// Right-aligned label (e.g. `Step 1 / 5`).
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color active = theme.colorScheme.primary;
    final Color inactive = theme.colorScheme.outlineVariant;

    return Row(
      children: <Widget>[
        for (int i = 0; i < total; i++) ...<Widget>[
          Container(
            width: AppSpacing.md,
            height: AppSpacing.md,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < current ? active : inactive,
            ),
          ),
          if (i != total - 1) const SizedBox(width: AppSpacing.sm),
        ],
        const Spacer(),
        Text(
          label,
          style: theme.textTheme.label.copyWith(color: context.palette.muted),
        ),
      ],
    );
  }
}
