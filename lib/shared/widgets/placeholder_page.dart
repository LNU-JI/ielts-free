import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';

/// A simple, consistent placeholder page used while a feature is under
/// development.
///
/// Every route referenced by `router.dart` resolves to a real page class so that
/// `flutter analyze` is clean and the empty shell runs. Feature pages will be
/// replaced with real implementations in T04; this widget keeps the V0.2
/// placeholders (Listening / Writing / Speaking / Statistics) consistent.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    this.icon,
    this.message,
    this.showAppBar = true,
  });

  /// Page title shown in the app bar and in the body.
  final String title;

  /// Optional leading icon.
  final IconData? icon;

  /// Optional body message (defaults to the generic "under development" text).
  final String? message;

  /// Whether to render an [AppBar]. Set to `false` when the page is hosted in a
  /// shell that already provides its own chrome.
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Widget body = Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon ?? Icons.construction_outlined,
              size: 48,
              color: context.palette.muted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message ?? AppStrings.placeholderMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.palette.muted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    if (!showAppBar) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}
