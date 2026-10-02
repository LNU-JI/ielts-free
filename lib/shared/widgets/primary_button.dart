import 'package:flutter/material.dart';

import 'package:ielts_free/app/theme.dart';

/// A primary action button that can show an inline loading state.
///
/// Wraps [FilledButton] so pages get a consistent minimum height / padding (set
/// in `theme.dart`) and a built-in spinner while an async action is running.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  });

  /// Button label (already localized).
  final String label;

  /// Tap handler; `null` (or [isLoading]) disables the button.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Whether to show a spinner and disable the button.
  final bool isLoading;

  /// Whether the button should fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isLoading;
    final Widget child = isLoading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);

    final Widget button = icon != null && !isLoading
        ? FilledButton.icon(
            onPressed: enabled ? onPressed : null,
            icon: Icon(icon),
            label: Text(label),
          )
        : FilledButton(
            onPressed: enabled ? onPressed : null,
            child: child,
          );

    if (!expand) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}

/// A secondary (outlined) action button used next to [PrimaryButton].
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
  });

  /// Button label (already localized).
  final String label;

  /// Tap handler.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Whether the button should fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Widget button = icon != null
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton(onPressed: onPressed, child: Text(label));

    if (!expand) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}

/// A slim spacer that keeps vertical rhythm on token values.
class AppGap extends StatelessWidget {
  const AppGap.sm({super.key}) : _size = AppSpacing.sm;
  const AppGap.md({super.key}) : _size = AppSpacing.md;
  const AppGap.lg({super.key}) : _size = AppSpacing.lg;
  const AppGap.xl({super.key}) : _size = AppSpacing.xl;

  final double _size;

  @override
  Widget build(BuildContext context) => SizedBox(height: _size);
}
