import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/features/vocabulary/application/vocab_question_builder.dart';
import 'package:ielts_free/features/vocabulary/application/vocabulary_practice_controller.dart';
import 'package:ielts_free/features/vocabulary/presentation/widgets/answer_feedback.dart';
import 'package:ielts_free/features/vocabulary/presentation/widgets/practice_question_view.dart';
import 'package:ielts_free/features/vocabulary/presentation/widgets/review_queue_header.dart';
import 'package:ielts_free/shared/widgets/adaptive_layout.dart';
import 'package:ielts_free/shared/widgets/empty_state.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';
import 'package:ielts_free/shared/widgets/primary_button.dart';

/// Vocabulary practice (full-screen route `/practice/vocabulary`, no shell).
///
/// Runs the seven question kinds (PRD §4.4), grades each answer through the
/// unified write path and checkpoints after every question.
class VocabularyPracticePage extends ConsumerStatefulWidget {
  const VocabularyPracticePage({super.key});

  @override
  ConsumerState<VocabularyPracticePage> createState() =>
      _VocabularyPracticePageState();
}

class _VocabularyPracticePageState
    extends ConsumerState<VocabularyPracticePage> {
  final TextEditingController _text = TextEditingController();
  String? _selected;
  int _lastIndex = -1;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<VocabPracticeState> async =
        ref.watch(vocabularyPracticeControllerProvider);
    final VocabularyPracticeController controller =
        ref.read(vocabularyPracticeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.vocabularyPracticeTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(AppRoutes.practice),
        ),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => const EmptyState(
          icon: Icons.error_outline,
          title: AppStrings.errorGeneric,
          message: AppStrings.errorGeneric,
        ),
        data: (VocabPracticeState data) => _body(context, data, controller),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    VocabPracticeState data,
    VocabularyPracticeController controller,
  ) {
    if (data.items.isEmpty) {
      return const EmptyState(
        icon: Icons.menu_book_outlined,
        title: AppStrings.vocabularyPracticeEmpty,
        message: AppStrings.vocabularyPracticeEmptyHint,
      );
    }
    if (data.finished) {
      return _summary(context, data, controller);
    }

    final VocabPracticeItem? item = data.current;
    if (item == null) {
      return const EmptyState(
        icon: Icons.menu_book_outlined,
        title: AppStrings.vocabularyPracticeEmpty,
        message: AppStrings.vocabularyPracticeEmptyHint,
      );
    }

    _syncDraft(data);

    final VocabAnswerRecord? record = data.currentRecord;
    final bool answered = record != null;
    final bool canSubmit = item.isChoice
        ? _selected != null
        : _text.text.trim().isNotEmpty;

    return ContentContainer(
      maxWidth: 720,
      child: ListView(
        children: <Widget>[
          ReviewQueueHeader(
            current: data.currentIndex + 1,
            total: data.total,
            elapsedSeconds: data.elapsedSeconds,
            title: AppStrings.vocabularyPracticeTitle,
          ),
          if (data.restored) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.vocabularyPracticeRestored,
              style: Theme.of(context).textTheme.caption.copyWith(
                    color: context.palette.warning,
                  ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          PracticeQuestionView(
            item: item,
            answered: answered,
            selected: _selected,
            textController: _text,
            submitting: data.submitting,
            onSelect: (String value) {
              setState(() => _selected = value);
              controller.saveDraft(value);
            },
            onSubmitted: (String value) => controller.answer(value),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (answered) ...<Widget>[
            AnswerFeedback(
              isCorrect: record.isCorrect,
              correctAnswer: record.correctAnswer,
              userAnswer: record.userAnswer,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: data.isComplete
                  ? AppStrings.vocabularyPracticeFinish
                  : AppStrings.vocabularyPracticeNext,
              expand: true,
              onPressed: controller.next,
            ),
          ] else
            PrimaryButton(
              label: AppStrings.submit,
              expand: true,
              isLoading: data.submitting,
              onPressed: canSubmit
                  ? () => controller.answer(
                        item.isChoice ? (_selected ?? '') : _text.text,
                      )
                  : null,
            ),
          if (data.error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              data.error!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summary(
    BuildContext context,
    VocabPracticeState data,
    VocabularyPracticeController controller,
  ) {
    final ThemeData theme = Theme.of(context);
    final int total = data.total;
    final int correct = data.correctCount;
    final int percent = total == 0 ? 0 : ((correct / total) * 100).round();

    return ContentContainer(
      maxWidth: 640,
      child: ListView(
        children: <Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text(
            AppStrings.vocabularyPracticeCompleteTitle,
            style: theme.textTheme.headline,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppStrings.vocabularyPracticeResult(correct, total),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.vocabularyPracticeAccuracy(percent),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.palette.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: AppStrings.vocabularyPracticeRestart,
            expand: true,
            onPressed: controller.restart,
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: AppStrings.back,
            expand: true,
            onPressed: () => context.go(AppRoutes.practice),
          ),
        ],
      ),
    );
  }

  /// Keeps the text field / option selection aligned with the current question.
  void _syncDraft(VocabPracticeState data) {
    if (_lastIndex == data.currentIndex) {
      return;
    }
    _lastIndex = data.currentIndex;
    _selected = null;
    final String draft = data.drafts[data.currentIndex] ?? '';
    _text.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }
}
