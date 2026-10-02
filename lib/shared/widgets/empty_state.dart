import 'package:flutter/material.dart';

import 'package:ielts_free/app/theme.dart';

/// A consistent empty-state block: icon, message and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.title,
    this.action,
  });

  /// Primary message (already localized).
  final String message;

  /// Optional heading above the message.
  final String? title;

  /// Leading icon.
  final IconData icon;

  /// Optional action widget (e.g. a [PrimaryButton]).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 40, color: context.palette.muted),
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
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.palette.muted,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
