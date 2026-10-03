import 'package:flutter/material.dart';

import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/enums/listening_error_type.dart';

/// The five-way mistake classifier — the heart of the intensive-listening loop.
///
/// Each option shows the short label and the one-line advice on how to fix that
/// class of mistake, so choosing a cause is itself a study action.
class ErrorTypeSelector extends StatelessWidget {
  const ErrorTypeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// The currently chosen cause, or `null`.
  final ListeningErrorType? selected;

  /// Called when the learner picks a cause.
  final ValueChanged<ListeningErrorType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final ListeningErrorType type in ListeningErrorType.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _TypeTile(
              type: type,
              selected: type == selected,
              onTap: () => onSelected(type),
            ),
          ),
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final ListeningErrorType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      borderRadius: AppRadius.mdAll,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.secondaryContainer : null,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: selected
                ? theme.colorScheme.secondary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(type.label, style: theme.textTheme.titleSmall),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: theme.colorScheme.secondary,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              type.hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
