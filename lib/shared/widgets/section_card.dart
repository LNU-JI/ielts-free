import 'package:flutter/material.dart';

import 'package:ielts_free/app/theme.dart';

/// A themed surface container used to group related content.
///
/// Centralises the card look (surface color, radius, padding) so pages never
/// hard-code a color or a corner radius (docs/ARCHITECTURE-v0.1.md §9.5).
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
  });

  /// Card content.
  final Widget child;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Optional tap handler; when set the card becomes tappable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget content = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: onTap == null
          ? content
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: AppRadius.mdAll,
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }
}
