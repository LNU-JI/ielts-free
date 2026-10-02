import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/reading_question.dart';
import 'package:ielts_free/features/reading/application/reading_session_controller.dart';
import 'package:ielts_free/features/reading/presentation/widgets/explanation_view.dart';
import 'package:ielts_free/features/reading/presentation/widgets/passage_view.dart';
import 'package:ielts_free/features/reading/presentation/widgets/question_navigator.dart';
import 'package:ielts_free/features/reading/presentation/widgets/question_view.dart';
import 'package:ielts_free/features/reading/presentation/widgets/session_timer.dart';
import 'package:ielts_free/shared/extensions/context_extensions.dart';
import 'package:ielts_free/shared/widgets/empty_state.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';
import 'package:ielts_free/shared/widgets/primary_button.dart';

/// Reading session / question screen (desktop shell route `/reading/:id`).
///
/// Desktop: passage on the left (55%), questions on the right (45%). Mobile:
/// passage above, questions below (PRD §4.5 / BRIEF §18). Keeps the question
/// number, progress and remaining time visible, and reveals the six-item
/// explanation after submission.
class ReadingSessionPage extends ConsumerStatefulWidget {
  const ReadingSessionPage({super.key, required this.passageId});

  /// Id of the passage (from the read-only content database).
  final int passageId;

  @override
  ConsumerState<ReadingSessionPage> createState() => _ReadingSessionPageState();
}

class _ReadingSessionPageState extends ConsumerState<ReadingSessionPage> {
  final TextEditingController _text = TextEditingController();
  int _lastQuestionId = -1;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ReadingSessionState> async =
        ref.watch(readingSessionControllerProvider(widget.passageId));
    final ReadingSessionController controller =
        ref.read(readingSessionControllerProvider(widget.passageId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.readingTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.reading),
        ),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => const ErrorView(
          title: AppStrings.readingSessionErrorTitle,
        ),
        data: (ReadingSessionState data) => _layout(context, data, controller),
      ),
    );
  }

  Widget _layout(
    BuildContext context,
    ReadingSessionState data,
    ReadingSessionController controller,
  ) {
    if (data.questions.isEmpty) {
      return const EmptyState(
        icon: Icons.article_outlined,
        title: AppStrings.readingListEmpty,
        message: AppStrings.readingListEmptyHint,
      );
    }
    _syncText(data);
    final List<Widget> questionWidgets = _questionChildren(context, data, controller);

    if (context.isDesktopLayout) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            flex: 55,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: PassageView(passage: data.passage),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            flex: 45,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: questionWidgets,
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        PassageView(passage: data.passage),
        const SizedBox(height: AppSpacing.lg),
        ...questionWidgets,
      ],
    );
  }

  List<Widget> _questionChildren(
    BuildContext context,
    ReadingSessionState data,
    ReadingSessionController controller,
  ) {
    final ThemeData theme = Theme.of(context);
    final ReadingQuestion question = data.current!;
    final int number = data.currentIndex + 1;

    final Set<int> answered = <int>{};
    final Map<int, bool> results = <int, bool>{};
    for (int i = 0; i < data.questions.length; i++) {
      final ReadingQuestion q = data.questions[i];
      if (data.answerFor(q.id).trim().isNotEmpty) {
        answered.add(i);
      }
      final bool? r = data.resultFor(q.id);
      if (r != null) {
        results[i] = r;
      }
    }

    return <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Text(
              AppStrings.readingQuestionOf(number, data.total),
              style: theme.textTheme.titleSmall,
            ),
          ),
          SessionTimer(remainingSeconds: data.remainingSeconds),
        ],
      ),
      if (data.restored) ...<Widget>[
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.vocabularyPracticeRestored,
          style: theme.textTheme.caption.copyWith(color: context.palette.warning),
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      QuestionNavigator(
        count: data.total,
        currentIndex: data.currentIndex,
        answered: answered,
        results: results,
        onSelect: (int index) => controller.goTo(index),
      ),
      const SizedBox(height: AppSpacing.lg),
      QuestionView(
        question: question,
        number: number,
        value: data.answerFor(question.id),
        textController: _text,
        readOnly: data.submitted,
        result: data.resultFor(question.id),
        onChanged: (String value) => controller.answer(value),
      ),
      if (data.submitted) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        ExplanationView(
          question: question,
          isCorrect: data.resultFor(question.id) ?? false,
          userAnswer: data.answerFor(question.id),
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
      const SizedBox(height: AppSpacing.lg),
      if (!data.submitted) ...<Widget>[
        PrimaryButton(
          label: AppStrings.readingSubmitAll,
          expand: true,
          isLoading: data.submitting,
          onPressed: data.allAnswered ? controller.submit : null,
        ),
        if (!data.allAnswered) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.vocabularyPracticeProgress(
              data.answeredCount,
              data.total,
            ),
            style: theme.textTheme.caption.copyWith(
              color: context.palette.muted,
            ),
          ),
        ],
      ] else ...<Widget>[
        if (data.autoSubmitted) ...<Widget>[
          Text(
            AppStrings.readingAutoSubmitted,
            style: theme.textTheme.caption.copyWith(
              color: context.palette.warning,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          AppStrings.readingResult(data.correctCount, data.total),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        SecondaryButton(
          label: AppStrings.vocabularyPracticeRestart,
          expand: true,
          onPressed: controller.restart,
        ),
      ],
      if (data.error != null) ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        Text(
          data.error!,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ],
    ];
  }

  /// Keeps the gap-fill text field aligned with the current question.
  void _syncText(ReadingSessionState data) {
    final ReadingQuestion? question = data.current;
    if (question == null || question.id == _lastQuestionId) {
      return;
    }
    _lastQuestionId = question.id;
    final String value = data.answerFor(question.id);
    _text.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}
