import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// A tappable hub entry (used by the Learn / Practice / Me tabs).
///
/// When [comingSoon] is set the tile is greyed out and shows a "V0.2" badge and
/// cannot be tapped (PRD Q-7).
class HubTile extends StatelessWidget {
  const HubTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.comingSoon = false,
  });

  /// Leading icon.
  final IconData icon;

  /// Tile title.
  final String title;

  /// Optional secondary line.
  final String? subtitle;

  /// Tap handler; ignored when [comingSoon] is `true`.
  final VoidCallback? onTap;

  /// Whether the entry is a V0.2 placeholder.
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color iconColor =
        comingSoon ? context.palette.muted : theme.colorScheme.secondary;
    final Color titleColor = comingSoon
        ? context.palette.muted
        : theme.colorScheme.onSurface;

    return SectionCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onTap: comingSoon ? null : onTap,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 24, color: iconColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(color: titleColor),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.caption.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (comingSoon)
            Text(
              AppStrings.comingSoon,
              style: theme.textTheme.caption.copyWith(
                color: context.palette.muted,
              ),
            )
          else
            Icon(
              Icons.chevron_right,
              size: 20,
              color: context.palette.muted,
            ),
        ],
      ),
    );
  }
}
