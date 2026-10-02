import 'package:flutter/material.dart';

import 'package:ielts_free/app/theme.dart';

/// A compact "value + label" tile (e.g. `D-58 天`, `25 min`).
///
/// Used by the Dashboard header and the streak card.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.valueColor,
    this.onTap,
  });

  /// Small caption shown under the value.
  final String label;

  /// The prominent value text.
  final String value;

  /// Optional unit appended after the value (e.g. `天` / `min`).
  final String? unit;

  /// Optional leading icon.
  final IconData? icon;

  /// Optional color for the value text; defaults to the theme's primary.
  final Color? valueColor;

  /// Optional tap handler.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color effectiveValueColor =
        valueColor ?? theme.colorScheme.primary;

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 18, color: effectiveValueColor),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: effectiveValueColor,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unit != null && unit!.isNotEmpty) ...<Widget>[
              const SizedBox(width: AppSpacing.xs),
              Text(
                unit!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.caption.copyWith(
            color: context.palette.muted,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }
    return InkWell(
      borderRadius: AppRadius.smAll,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: content,
      ),
    );
  }
}
