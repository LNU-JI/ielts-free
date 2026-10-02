import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';

/// A centered loading indicator with an optional caption.
///
/// Used as the `loading:` branch of every `AsyncValue.when` in the app so the
/// look stays consistent.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = AppStrings.loading});

  /// Caption shown under the spinner.
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
