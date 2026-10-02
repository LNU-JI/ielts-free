import 'package:flutter/material.dart';

import 'package:ielts_free/app/theme.dart';

/// A section title with an optional trailing action.
///
/// Used to head the cards on the Dashboard / Settings / Study Plan pages.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.sm),
  });

  /// Section title (already localized via `strings.dart`).
  final String title;

  /// Optional widget shown at the end of the row (e.g. a text button).
  final Widget? trailing;

  /// Outer padding; defaults to a small gap below the header.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
