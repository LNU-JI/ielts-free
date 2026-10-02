import 'package:flutter/material.dart';

import 'package:ielts_free/app/theme.dart';

/// A labelled ability bar (0–100).
///
/// Used by the Dashboard "我的能力" block. The value is shown as an integer and
/// the fill is proportional; the color comes from the theme so no page needs a
/// hard-coded value (docs/ARCHITECTURE-v0.1.md §9.5, PRD Q-4).
class SkillBar extends StatelessWidget {
  const SkillBar({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.trailing,
  });

  /// Skill label (e.g. `Vocab`).
  final String label;

  /// Score in `[0, 100]`; out-of-range values are clamped.
  final int value;

  /// Optional fill color; defaults to the theme's secondary color.
  final Color? color;

  /// Optional trailing widget (e.g. a tap target).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double ratio = (value.clamp(0, 100)) / 100.0;

    final Widget bar = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$value',
              style: theme.textTheme.label.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: AppRadius.smAll,
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: AppSpacing.sm,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? theme.colorScheme.secondary,
            ),
          ),
        ),
      ],
    );

    if (trailing == null) {
      return bar;
    }
    return Row(
      children: <Widget>[
        Expanded(child: bar),
        const SizedBox(width: AppSpacing.sm),
        trailing!,
      ],
    );
  }
}
