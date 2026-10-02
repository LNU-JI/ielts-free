import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/providers/bootstrap_provider.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';

/// Startup screen shown while the app prepares its local databases.
///
/// The progress bar is driven by [bootstrapProgressProvider]; if startup fails
/// the user can retry, which re-runs the whole sequence (docs/ARCHITECTURE §6.1).
class BootstrapPage extends ConsumerWidget {
  const BootstrapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<BootstrapState> bootstrap =
        ref.watch(bootstrapControllerProvider);

    if (bootstrap.hasError) {
      return Scaffold(
        body: ErrorView(
          title: AppStrings.appName,
          onRetry: () => ref.invalidate(bootstrapControllerProvider),
        ),
      );
    }

    // During startup the controller is still `AsyncLoading`, so the live
    // progress is streamed through `bootstrapProgressProvider`; once startup
    // completes we fall back to the value carried by the state.
    final double streamedProgress = ref.watch(bootstrapProgressProvider);
    final double progress =
        bootstrap.valueOrNull?.progress ?? streamedProgress;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.school,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(AppStrings.appName, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 220,
                child: LinearProgressIndicator(
                  value: progress > 0.0 && progress < 1.0 ? progress : null,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(AppStrings.loading, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
