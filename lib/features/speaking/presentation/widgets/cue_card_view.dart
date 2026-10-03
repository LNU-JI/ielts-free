import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// The Part 2 cue card (提纲卡).
///
/// Shown before the preparation countdown starts, and kept on screen while the
/// learner takes notes and answers.
class CueCardView extends StatelessWidget {
  const CueCardView({super.key, required this.text});

  /// The cue card body.
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.description_outlined,
                size: 18,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(AppStrings.speakingCueCard, style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
