import 'package:flutter/material.dart';

import 'package:ielts_free/app/theme.dart';

/// A themed horizontal progress bar with an optional caption.
///
/// Thin wrapper over [LinearProgressIndicator] that keeps the height and radius
/// on the design tokens (docs/ARCHITECTURE-v0.1.md §9.5).
class LinearProgressBar extends StatelessWidget {
  const LinearProgressBar({
    super.key,
    required this.value,
    this.height = AppSpacing.sm,
    this.caption,
  });

  /// Progress in `[0, 1]`; `null` renders an indeterminate bar.
  final double? value;

  /// Bar thickness.
  final double height;

  /// Optional caption shown above the bar.
  final Widget? caption;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? ratio = value?.clamp(0.0, 1.0).toDouble();

    final Widget bar = ClipRRect(
      borderRadius: AppRadius.smAll,
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: height,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
      ),
    );

    if (caption == null) {
      return bar;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        caption!,
        const SizedBox(height: AppSpacing.xs),
        bar,
      ],
    );
  }
}
