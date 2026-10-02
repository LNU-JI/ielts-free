import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/mistake.dart';
import 'package:ielts_free/features/mistakes/application/mistake_detail_controller.dart';
import 'package:ielts_free/features/mistakes/application/mistake_labels.dart';
import 'package:ielts_free/features/reading/presentation/widgets/explanation_view.dart';
import 'package:ielts_free/features/reading/presentation/widgets/question_view.dart';
import 'package:ielts_free/features/vocabulary/presentation/widgets/word_card.dart';
import 'package:ielts_free/shared/widgets/adaptive_layout.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/linear_progress_bar.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';
import 'package:ielts_free/shared/widgets/primary_button.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// Mistake detail with re-do (mobile shell route `/mistakes/:id`, PRD §4.6).
///
/// Shows the user's answer beside the correct one, the six-item explanation (for
/// reading) or the word card (for vocabulary), a mastery bar, and a redo area
/// that evolves mastery through the unified write path.
class MistakeDetailPage extends ConsumerStatefulWidget {
  const MistakeDetailPage({super.key, required this.mistakeId});

  /// Identifier of the mistake record.
  final String mistakeId;

  @override
  ConsumerState<MistakeDetailPage> createState() => _MistakeDetailPageState();
}

class _MistakeDetailPageState extends ConsumerState<MistakeDetailPage> {
  final TextEditingController _redoText = TextEditingController();
  String _redo = '';

  @override
  void dispose() {
    _redoText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int? id = int.tryParse(widget.mistakeId);
    if (id == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.mistakesDetailTitle)),
        body: const ErrorView(title: AppStrings.mistakesDetailErrorTitle),
      );
    }

    final AsyncValue<MistakeDetailState> async =
        ref.watch(mistakeDetailControllerProvider(id));
    final MistakeDetailController controller =
        ref.read(mistakeDetailControllerProvider(id).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.mistakesDetailTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.mistakes),
        ),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => const ErrorView(
          title: AppStrings.mistakesDetailErrorTitle,
        ),
        data: (MistakeDetailState data) => _body(context, data, controller),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    MistakeDetailState data,
    MistakeDetailController controller,
  ) {
    final ThemeData theme = Theme.of(context);
    final Mistake mistake = data.mistake;

    return ContentContainer(
      maxWidth: 720,
      child: ListView(
        children: <Widget>[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    if (MistakeLabels.questionType(mistake.questionType).isNotEmpty)
                      _Tag(
                        label: AppStrings.mistakesTypeLabel,
                        value: MistakeLabels.questionType(mistake.questionType),
                      ),
                    if (MistakeLabels.errorType(mistake.errorType).isNotEmpty)
                      _Tag(
                        label: AppStrings.mistakesErrorTypeLabel,
                        value: MistakeLabels.errorType(mistake.errorType),
                      ),
                    if (MistakeLabels.skill(mistake.skill).isNotEmpty)
                      _Tag(
                        label: AppStrings.mistakesSkillLabel,
                        value: MistakeLabels.skill(mistake.skill),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _Line(
                  label: AppStrings.mistakesYourAnswer,
                  value: (mistake.userAnswer ?? '').trim().isEmpty
                      ? AppStrings.readingNoAnswer
                      : mistake.userAnswer!,
                ),
                _Line(
                  label: AppStrings.mistakesCorrectAnswer,
                  value: mistake.correctAnswer ?? '',
                ),
                const SizedBox(height: AppSpacing.md),
                LinearProgressBar(
                  value: data.mastery,
                  caption: Text(
                    AppStrings.mistakesMasteryPercent(
                      (data.mastery * 100).round(),
                    ),
                    style: theme.textTheme.caption.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ),
                if (data.isMastered) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppStrings.mistakesMasteredTag,
                    style: theme.textTheme.caption.copyWith(
                      color: context.palette.success,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (data.readingQuestion != null)
            ExplanationView(
              question: data.readingQuestion!,
              isCorrect: false,
              userAnswer: mistake.userAnswer,
            ),
          if (data.vocabulary != null) ...<Widget>[
            WordCard(vocabulary: data.vocabulary!),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (data.canRedo) _redoSection(context, data, controller),
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

  Widget _redoSection(
    BuildContext context,
    MistakeDetailState data,
    MistakeDetailController controller,
  ) {
    final ThemeData theme = Theme.of(context);
    final bool isReading = data.readingQuestion != null;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(AppStrings.mistakesRedo, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.md),
          if (isReading)
            QuestionView(
              question: data.readingQuestion!,
              number: 1,
              value: _redo,
              textController: _redoText,
              onChanged: (String value) => setState(() => _redo = value),
            )
          else ...<Widget>[
            Text(
              data.vocabulary!.meaningCn,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _redoText,
              textInputAction: TextInputAction.done,
              onChanged: (String value) => setState(() => _redo = value),
              decoration: const InputDecoration(
                hintText: AppStrings.vocabularyPracticeSpellingHint,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: AppStrings.mistakesRedo,
            expand: true,
            isLoading: data.busy,
            onPressed: _redo.trim().isEmpty ? null : () => controller.redo(_redo),
          ),
          if (data.lastRedoCorrect != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              data.lastRedoCorrect!
                  ? AppStrings.mistakesRedoCorrect
                  : AppStrings.mistakesRedoWrong,
              style: theme.textTheme.bodySmall?.copyWith(
                color: data.lastRedoCorrect!
                    ? context.palette.success
                    : theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.caption.copyWith(color: context.palette.muted),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.smAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        '$label：$value',
        style: theme.textTheme.caption,
      ),
    );
  }
}
