import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/features/speaking/application/speaking_session_controller.dart';
import 'package:ielts_free/features/speaking/presentation/widgets/speaking_timer.dart';
import 'package:ielts_free/shared/widgets/primary_button.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// The recording controls of the speaking session.
///
/// Shows the active countdown, the microphone status, the primary action for the
/// current stage and — during the Part 2 preparation — the note pad. When the
/// microphone permission has been refused the countdown still runs and the
/// question, model answer and timer stay available (graceful degradation,
/// BRIEF §20): the learner just practises aloud without a recording.
class RecordingPanel extends StatefulWidget {
  const RecordingPanel({
    super.key,
    required this.state,
    required this.onStart,
    required this.onSkipPrep,
    required this.onStop,
    required this.onNotesChanged,
  });

  /// The current session state.
  final SpeakingSessionState state;

  /// Starts the current question (preparation first for Part 2).
  final VoidCallback onStart;

  /// Skips the preparation and starts answering.
  final VoidCallback onSkipPrep;

  /// Stops the answer early.
  final VoidCallback onStop;

  /// Called as the preparation notes change.
  final ValueChanged<String> onNotesChanged;

  @override
  State<RecordingPanel> createState() => _RecordingPanelState();
}

class _RecordingPanelState extends State<RecordingPanel> {
  late final TextEditingController _notes =
      TextEditingController(text: widget.state.notes);
  int _questionId = -1;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RecordingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int id = widget.state.current?.id ?? -1;
    if (id != _questionId) {
      _questionId = id;
      _notes.text = widget.state.notes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SpeakingSessionState state = widget.state;
    final bool active = state.phase == SpeakingPhase.prep ||
        state.phase == SpeakingPhase.speaking;
    final bool micDenied = state.micGranted == false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (active)
          SectionCard(
            child: SpeakingTimer(
              label: state.phase == SpeakingPhase.prep
                  ? AppStrings.speakingPreparation
                  : AppStrings.speakingSpeaking,
              remainingSeconds: state.remainingSeconds,
              totalSeconds: state.totalSeconds,
            ),
          ),
        if (micDenied) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.mic_off_outlined,
                size: 18,
                color: context.palette.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppStrings.speakingMicDenied,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.palette.warning,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _actions(state),
        if (state.phase == SpeakingPhase.prep) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: 6,
            onChanged: widget.onNotesChanged,
          ),
        ],
      ],
    );
  }

  Widget _actions(SpeakingSessionState state) {
    switch (state.phase) {
      case SpeakingPhase.ready:
        return PrimaryButton(
          label: state.needsPrep
              ? AppStrings.speakingStartPrep
              : AppStrings.speakingStartSpeaking,
          icon: Icons.mic_none_outlined,
          expand: true,
          onPressed: widget.onStart,
        );
      case SpeakingPhase.prep:
        return PrimaryButton(
          label: AppStrings.speakingStartSpeaking,
          icon: Icons.mic_none_outlined,
          expand: true,
          onPressed: widget.onSkipPrep,
        );
      case SpeakingPhase.speaking:
        return PrimaryButton(
          label: AppStrings.speakingStop,
          icon: Icons.stop_circle_outlined,
          expand: true,
          onPressed: widget.onStop,
        );
      case SpeakingPhase.review:
      case SpeakingPhase.finished:
        return const SizedBox.shrink();
    }
  }
}
