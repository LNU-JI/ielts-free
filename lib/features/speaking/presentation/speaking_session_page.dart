import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/speaking_question.dart';
import 'package:ielts_free/features/speaking/application/speaking_session_controller.dart';
import 'package:ielts_free/features/speaking/presentation/widgets/cue_card_view.dart';
import 'package:ielts_free/features/speaking/presentation/widgets/question_prompt.dart';
import 'package:ielts_free/features/speaking/presentation/widgets/recording_panel.dart';
import 'package:ielts_free/features/speaking/presentation/widgets/sample_answer_view.dart';
import 'package:ielts_free/features/speaking/presentation/widgets/self_rating_view.dart';
import 'package:ielts_free/shared/widgets/adaptive_layout.dart';
import 'package:ielts_free/shared/widgets/empty_state.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/linear_progress_bar.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';
import 'package:ielts_free/shared/widgets/primary_button.dart';

/// Speaking practice session (desktop shell route `/speaking/:id`).
///
/// Runs one topic: the cue card and the examiner's question, the timed answer
/// (with recording when the microphone is available), then the replay, the
/// five-item self-assessment and the model answer. Nothing is uploaded and no
/// AI scoring is involved — the checklist is the offline substitute.
class SpeakingSessionPage extends ConsumerWidget {
  const SpeakingSessionPage({super.key, required this.topicId});

  /// Id of the topic (from the read-only content database).
  final int topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SpeakingSessionState> async =
        ref.watch(speakingSessionControllerProvider(topicId));
    final SpeakingSessionController controller =
        ref.read(speakingSessionControllerProvider(topicId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.speakingTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.speaking),
        ),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => ErrorView(
          title: AppStrings.speakingTitle,
          onRetry: () => ref.invalidate(
            speakingSessionControllerProvider(topicId),
          ),
        ),
        data: (SpeakingSessionState data) => data.questions.isEmpty
            ? const EmptyState(
                icon: Icons.record_voice_over_outlined,
                message: AppStrings.speakingEmpty,
              )
            : _content(context, data, controller),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    SpeakingSessionState data,
    SpeakingSessionController controller,
  ) {
    final ThemeData theme = Theme.of(context);
    final SpeakingQuestion? question = data.current;
    final bool reviewing = data.phase == SpeakingPhase.review;
    final bool finished = data.phase == SpeakingPhase.finished;

    return ContentContainer(
      maxWidth: 720,
      padding: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          LinearProgressBar(
            value: data.progress,
            caption: Text(
              AppStrings.vocabularyPracticeProgress(data.savedCount, data.total),
              style: theme.textTheme.caption.copyWith(
                color: context.palette.muted,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (data.topic.hasCueCard) ...<Widget>[
            CueCardView(text: data.topic.cueCard!),
            const SizedBox(height: AppSpacing.md),
          ],
          if (question != null) ...<Widget>[
            QuestionPrompt(
              question: question,
              number: data.currentIndex + 1,
              total: data.total,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (reviewing && data.timedOut) ...<Widget>[
            Text(
              AppStrings.speakingTimeUp,
              style: theme.textTheme.caption.copyWith(
                color: context.palette.warning,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          RecordingPanel(
            state: data,
            onStart: controller.start,
            onSkipPrep: controller.skipPrep,
            onStop: controller.stop,
            onNotesChanged: controller.setNotes,
          ),
          if (reviewing && question != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: AppStrings.speakingReplay,
              icon: Icons.play_arrow_outlined,
              expand: true,
              onPressed: controller.replay,
            ),
            const SizedBox(height: AppSpacing.md),
            SelfRatingView(
              key: ValueKey<int>(question.id),
              rating: data.currentRating ?? const SpeakingSelfRating(),
              onRate: controller.rateItem,
              onNoteChanged: controller.setRatingNote,
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: AppStrings.save,
              expand: true,
              isLoading: data.busy,
              onPressed: data.canSave ? controller.saveRating : null,
            ),
          ],
          if ((reviewing || finished) && question != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            SampleAnswerView(question: question),
          ],
          if (finished) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: AppStrings.vocabularyPracticeRestart,
              icon: Icons.refresh,
              expand: true,
              onPressed: controller.restart,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: SecondaryButton(
                  label: AppStrings.readingPrev,
                  expand: true,
                  onPressed: data.currentIndex > 0 ? controller.previous : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SecondaryButton(
                  label: AppStrings.readingNext,
                  expand: true,
                  onPressed: data.currentIndex < data.total - 1
                      ? controller.next
                      : null,
                ),
              ),
            ],
          ),
          if (data.error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              data.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
