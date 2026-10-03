import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/writing_sample.dart';
import 'package:ielts_free/core/models/writing_task.dart';
import 'package:ielts_free/features/writing/application/writing_controller.dart';
import 'package:ielts_free/features/writing/presentation/widgets/phrase_bank_view.dart';
import 'package:ielts_free/features/writing/presentation/widgets/sample_comparison_view.dart';
import 'package:ielts_free/features/writing/presentation/widgets/writing_chart.dart';
import 'package:ielts_free/features/writing/presentation/widgets/writing_outline_view.dart';
import 'package:ielts_free/shared/extensions/context_extensions.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/linear_progress_bar.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';
import 'package:ielts_free/shared/widgets/primary_button.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';
import 'package:ielts_free/shared/widgets/section_header.dart';

/// Writing session / timed attempt screen (desktop shell route `/writing/:id`).
///
/// Desktop: prompt + chart + outline + model essay on the left (55%), the
/// editor, live word count, clock, save action and phrase bank on the right
/// (45%). Mobile: the same sections stacked in one scroll view. There is no AI
/// feedback — the model essay and the phrase bank are the offline substitutes.
class WritingSessionPage extends ConsumerStatefulWidget {
  const WritingSessionPage({super.key, required this.taskId});

  /// Id of the writing task (from the read-only content database).
  final int taskId;

  @override
  ConsumerState<WritingSessionPage> createState() => _WritingSessionPageState();
}

class _WritingSessionPageState extends ConsumerState<WritingSessionPage> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<WritingSessionState> async =
        ref.watch(writingSessionControllerProvider(widget.taskId));
    final WritingSessionController controller =
        ref.read(writingSessionControllerProvider(widget.taskId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.writingTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.writing),
        ),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) =>
            const ErrorView(title: AppStrings.writingTitle),
        data: (WritingSessionState data) => _layout(context, data, controller),
      ),
    );
  }

  Widget _layout(
    BuildContext context,
    WritingSessionState data,
    WritingSessionController controller,
  ) {
    _syncText(data);
    final List<Widget> prompt = _promptChildren(context, data, controller);
    final List<Widget> writing = _writingChildren(context, data, controller);

    if (context.isDesktopLayout) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            flex: 55,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: prompt,
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            flex: 45,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: writing,
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[...prompt, ...writing],
    );
  }

  // --- prompt / chart / outline / model essay -----------------------------

  List<Widget> _promptChildren(
    BuildContext context,
    WritingSessionState data,
    WritingSessionController controller,
  ) {
    final ThemeData theme = Theme.of(context);
    final WritingTask task = data.task;
    final List<WritingOutlinePoint> outline = _outlineOf(task);
    final bool finished = data.phase == WritingPhase.finished;

    return <Widget>[
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(task.taskLabel, style: theme.textTheme.titleSmall),
                if (task.difficulty != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    AppStrings.vocabularyDifficultyLabel(task.difficulty!),
                    style: theme.textTheme.caption.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppStrings.writingPrompt,
              style: theme.textTheme.caption.copyWith(
                color: context.palette.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(task.prompt, style: theme.textTheme.bodyLarge),
            if (data.restored) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppStrings.vocabularyPracticeRestored,
                style: theme.textTheme.caption.copyWith(
                  color: context.palette.warning,
                ),
              ),
            ],
          ],
        ),
      ),
      if (task.isTask1 && task.hasChartData) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionHeader(title: AppStrings.writingChart),
              WritingChart(data: WritingChartData.fromMap(task.chartData!)),
            ],
          ),
        ),
      ],
      if (outline.isNotEmpty) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        SecondaryButton(
          label: AppStrings.writingOutline,
          icon: Icons.list_alt_outlined,
          expand: true,
          onPressed: controller.toggleOutline,
        ),
        if (data.showOutline) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          SectionCard(child: WritingOutlineView(outline: outline)),
        ],
      ],
      if (finished && task.samples.isNotEmpty) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        SecondaryButton(
          label: AppStrings.writingSample,
          icon: Icons.menu_book_outlined,
          expand: true,
          onPressed: controller.toggleSample,
        ),
        if (data.showSample) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          SectionCard(child: SampleComparisonView(samples: task.samples)),
        ],
      ],
    ];
  }

  // --- editor / clock / save / phrase bank --------------------------------

  List<Widget> _writingChildren(
    BuildContext context,
    WritingSessionState data,
    WritingSessionController controller,
  ) {
    final ThemeData theme = Theme.of(context);
    final bool finished = data.phase == WritingPhase.finished;

    return <Widget>[
      _stats(context, data),
      const SizedBox(height: AppSpacing.lg),
      Text(AppStrings.writingYourEssay, style: theme.textTheme.titleSmall),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        controller: _text,
        maxLines: null,
        minLines: 10,
        readOnly: finished,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        onChanged: controller.updateContent,
        style: theme.textTheme.bodyLarge,
        decoration: const InputDecoration(
          hintText: AppStrings.writingYourEssay,
        ),
      ),
      if (!finished && data.underLength) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppStrings.writingUnderLength,
          style: theme.textTheme.caption.copyWith(color: context.palette.warning),
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      if (!finished) ...<Widget>[
        _selfRating(context, data, controller),
        const SizedBox(height: AppSpacing.md),
        if (data.phase == WritingPhase.ready)
          PrimaryButton(
            label: AppStrings.writingStartWriting,
            expand: true,
            onPressed: controller.start,
          )
        else if (data.phase == WritingPhase.writing) ...<Widget>[
          if (data.timeUp) ...<Widget>[
            Text(
              AppStrings.speakingTimeUp,
              style: theme.textTheme.caption.copyWith(
                color: context.palette.warning,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          PrimaryButton(
            label: AppStrings.writingSave,
            expand: true,
            isLoading: data.saving,
            onPressed: data.isEmptyDraft ? null : controller.save,
          ),
        ],
      ] else ...<Widget>[
        Text(
          AppStrings.writingSaved,
          style: theme.textTheme.titleSmall?.copyWith(
            color: context.palette.success,
          ),
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
      const SizedBox(height: AppSpacing.xl),
      const SectionHeader(title: AppStrings.writingPhraseBank),
      const PhraseBankView(),
    ];
  }

  Widget _stats(BuildContext context, WritingSessionState data) {
    final ThemeData theme = Theme.of(context);
    final bool urgent =
        data.phase == WritingPhase.writing && data.remainingSeconds <= 60;
    final Color timeColor =
        urgent ? context.palette.warning : context.palette.muted;
    final bool met = data.wordCount >= data.task.minWords;
    final Color countColor =
        met ? context.palette.success : context.palette.muted;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.timer_outlined, size: 16, color: timeColor),
              const SizedBox(width: AppSpacing.xs),
              Text(
                AppStrings.writingTimeLeft,
                style: theme.textTheme.caption.copyWith(
                  color: context.palette.muted,
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(data.remainingSeconds),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: timeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressBar(value: data.progress),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Text(
                AppStrings.writingWordCount,
                style: theme.textTheme.caption.copyWith(
                  color: context.palette.muted,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${data.wordCount}',
                style: theme.textTheme.titleSmall?.copyWith(color: countColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '${AppStrings.writingTargetWords} ${data.task.minWords} '
                '${AppStrings.wordsUnit}',
                style: theme.textTheme.caption.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _selfRating(
    BuildContext context,
    WritingSessionState data,
    WritingSessionController controller,
  ) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.writingSelfRating,
          style: theme.textTheme.caption.copyWith(
            color: context.palette.muted,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final String option in AppStrings.onboardingTestOptions)
              ChoiceChip(
                label: Text(option),
                selected: data.selfRating == option,
                onSelected: (bool selected) =>
                    controller.setSelfRating(selected ? option : null),
              ),
          ],
        ),
      ],
    );
  }

  /// Keeps the editor in step with the controller (restore / restart).
  ///
  /// During typing both sides already hold the same text, so this is a no-op
  /// then and never fights the user's cursor.
  void _syncText(WritingSessionState data) {
    if (data.content == _text.text) {
      return;
    }
    _text.value = TextEditingValue(
      text: data.content,
      selection: TextSelection.collapsed(offset: data.content.length),
    );
  }
}

/// The first model essay's outline, or an empty list when there is none.
List<WritingOutlinePoint> _outlineOf(WritingTask task) =>
    task.samples.isEmpty
        ? const <WritingOutlinePoint>[]
        : task.samples.first.outline;

/// Formats [seconds] as `mm:ss`.
String _formatTime(int seconds) {
  final int safe = seconds < 0 ? 0 : seconds;
  final int minutes = safe ~/ 60;
  final int secs = safe % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${secs.toString().padLeft(2, '0')}';
}
