import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/errors/result.dart';

/// A consistent error block with an optional retry action.
///
/// Accepts either a plain [message] or a [Failure] (whose `message` is already
/// user-safe). Technical details never reach the UI (docs/ARCHITECTURE-v0.1.md
/// §9.2). When neither is supplied a generic message is shown.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.message,
    this.failure,
    this.onRetry,
    this.title,
  });

  /// Explicit, already-localized message.
  final String? message;

  /// A [Failure] whose `message` will be shown.
  final Failure? failure;

  /// Optional retry callback; when set a "重试" button is shown.
  final VoidCallback? onRetry;

  /// Optional heading above the message.
  final String? title;

  /// The message that will actually be displayed.
  String get _text => message ?? failure?.message ?? AppStrings.errorGeneric;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 40,
              color: theme.colorScheme.error,
            ),
            if (title != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                title!,
                style: theme.textTheme.titleSmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              _text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.palette.muted,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text(AppStrings.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
