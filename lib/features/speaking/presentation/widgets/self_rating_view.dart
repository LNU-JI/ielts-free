import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/features/speaking/application/speaking_session_controller.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// The five-item self-assessment checklist (自评清单).
///
/// This is the offline stand-in for AI pronunciation scoring, which this app
/// deliberately does not do: the learner replays the recording and grades their
/// own fluency, clarity, pace, content and grammar on a 1–5 scale, and may add
/// a note. Every item must be scored before the answer can be saved.
class SelfRatingView extends StatefulWidget {
  const SelfRatingView({
    super.key,
    required this.rating,
    required this.onRate,
    required this.onNoteChanged,
  });

  /// The current scores (zero for unscored items).
  final SpeakingSelfRating rating;

  /// Called when one checklist item is scored.
  final void Function(SpeakingRatingItem item, int score) onRate;

  /// Called as the note changes.
  final ValueChanged<String> onNoteChanged;

  @override
  State<SelfRatingView> createState() => _SelfRatingViewState();
}

class _SelfRatingViewState extends State<SelfRatingView> {
  late final TextEditingController _note =
      TextEditingController(text: widget.rating.note);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.speakingSelfRating,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final SpeakingRatingItem item in SpeakingRatingItem.values)
            _RatingRow(
              label: _label(item),
              value: _value(item),
              onChanged: (int score) => widget.onRate(item, score),
            ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 4,
            onChanged: widget.onNoteChanged,
          ),
        ],
      ),
    );
  }

  int _value(SpeakingRatingItem item) {
    switch (item) {
      case SpeakingRatingItem.fluency:
        return widget.rating.fluency;
      case SpeakingRatingItem.clarity:
        return widget.rating.clarity;
      case SpeakingRatingItem.pace:
        return widget.rating.pace;
      case SpeakingRatingItem.content:
        return widget.rating.content;
      case SpeakingRatingItem.grammar:
        return widget.rating.grammar;
    }
  }

  String _label(SpeakingRatingItem item) {
    switch (item) {
      case SpeakingRatingItem.fluency:
        return AppStrings.speakingRateFluency;
      case SpeakingRatingItem.clarity:
        return AppStrings.speakingRateClarity;
      case SpeakingRatingItem.pace:
        return AppStrings.speakingRatePace;
      case SpeakingRatingItem.content:
        return AppStrings.speakingRateContent;
      case SpeakingRatingItem.grammar:
        return AppStrings.speakingRateGrammar;
    }
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          for (int score = 1; score <= SpeakingSelfRating.maxScore; score++)
            InkResponse(
              onTap: () => onChanged(score),
              radius: 18,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(
                  score <= value ? Icons.star : Icons.star_border,
                  size: 22,
                  color: score <= value
                      ? context.palette.warning
                      : context.palette.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
