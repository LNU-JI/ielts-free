import 'package:flutter/material.dart';

import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/writing_sample.dart';

/// A numbered paragraph-by-paragraph outline of a model essay.
///
/// Shown both as an optional pre-writing scaffold and inside the model-essay
/// panel after the attempt is saved.
class WritingOutlineView extends StatelessWidget {
  const WritingOutlineView({super.key, required this.outline});

  /// The outline points.
  final List<WritingOutlinePoint> outline;

  @override
  Widget build(BuildContext context) {
    if (outline.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < outline.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.caption.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        outline[i].section,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        outline[i].content,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
