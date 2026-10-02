import 'package:flutter/material.dart';

import 'package:ielts_free/app/theme.dart';

/// A single-select list of options rendered as a wrapping grid of chips.
///
/// Shared by the Onboarding steps so each step file stays tiny and the
/// selection look is identical everywhere.
class OptionSelector<T> extends StatelessWidget {
  const OptionSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.spacing = AppSpacing.sm,
  });

  /// Selectable values.
  final List<T> options;

  /// The currently selected value (`null` when nothing is selected yet).
  final T? selected;

  /// Maps a value to its display label.
  final String Function(T value) labelOf;

  /// Called when a value is tapped.
  final ValueChanged<T> onSelected;

  /// Gap between chips.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: <Widget>[
        for (final T option in options)
          ChoiceChip(
            label: Text(labelOf(option)),
            selected: selected == option,
            onSelected: (_) => onSelected(option),
            labelStyle: theme.textTheme.bodyMedium,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          ),
      ],
    );
  }
}
