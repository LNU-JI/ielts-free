import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/core/models/enums/listening_error_type.dart';
import 'package:ielts_free/core/models/listening_cue.dart';
import 'package:ielts_free/core/models/listening_question.dart';
import 'package:ielts_free/core/models/listening_section.dart';
import 'package:ielts_free/features/listening/application/listening_controller.dart';
import 'package:ielts_free/features/listening/application/listening_tts_service.dart';
import 'package:ielts_free/features/listening/presentation/widgets/cue_tile.dart';
import 'package:ielts_free/features/listening/presentation/widgets/error_type_selector.dart';
import 'package:ielts_free/features/listening/presentation/widgets/listening_explanation_view.dart';
import 'package:ielts_free/features/listening/presentation/widgets/listening_question_view.dart';
import 'package:ielts_free/features/listening/presentation/widgets/listening_step_bar.dart';
import 'package:ielts_free/shared/widgets/adaptive_layout.dart';
import 'package:ielts_free/shared/widgets/empty_state.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';
import 'package:ielts_free/shared/widgets/primary_button.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// Intensive-listening session screen (desktop shell route `/listening/:id`).
///
/// Walks one section through the six-step loop: 盲听 → 逐句听写 → 对照原文 →
/// 错因分类 → 跟读模仿 → 整段复听. Audio is synthesised on device from the cue
/// transcripts; when TTS is unavailable the screen degrades to a text-only
/// drill instead of failing.
class ListeningSessionPage extends ConsumerStatefulWidget {
  const ListeningSessionPage({super.key, required this.sectionId});

  /// Id of the section (from the read-only content database).
  final int sectionId;

  @override
  ConsumerState<ListeningSessionPage> createState() =>
      _ListeningSessionPageState();
}

class _ListeningSessionPageState extends ConsumerState<ListeningSessionPage> {
  final TextEditingController _dictation = TextEditingController();
  final Map<int, TextEditingController> _answerControllers =
      <int, TextEditingController>{};

  late final ListeningTtsService _tts;
  bool _ttsInitStarted = false;
  bool _ttsAvailable = false;
  bool _speaking = false;
  bool _slow = false;
  bool _showTranslation = false;
  bool _showTranscript = true;
  int _lastCueId = -1;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(listeningTtsProvider);
    _tts.onSpeakingChanged = _onSpeakingChanged;
  }

  @override
  void dispose() {
    _tts.onSpeakingChanged = null;
    _tts.stop();
    _dictation.dispose();
    for (final TextEditingController controller in _answerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ListeningSessionState> async =
        ref.watch(listeningSessionControllerProvider(widget.sectionId));
    final ListeningSessionController controller = ref.read(
      listeningSessionControllerProvider(widget.sectionId).notifier,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.listeningTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _exit(context, controller),
        ),
        actions: <Widget>[
          if (_speaking)
            IconButton(
              icon: const Icon(Icons.stop),
              tooltip: AppStrings.speakingStop,
              onPressed: _stop,
            ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => const ErrorView(
          title: AppStrings.listeningTitle,
        ),
        data: (ListeningSessionState data) {
          _ensureTts(data.section.accent);
          _syncDictation(data);
          return _body(context, data, controller);
        },
      ),
    );
  }

  // --- layout -------------------------------------------------------------

  Widget _body(
    BuildContext context,
    ListeningSessionState data,
    ListeningSessionController controller,
  ) {
    final ThemeData theme = Theme.of(context);
    if (data.cues.isEmpty && data.questions.isEmpty) {
      return const EmptyState(
        icon: Icons.headphones_outlined,
        message: AppStrings.listeningEmpty,
      );
    }
    return ContentContainer(
      maxWidth: 840,
      child: Column(
        children: <Widget>[
          ListeningStepBar(
            current: data.step,
            onSelect: controller.setStep,
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: <Widget>[
                Text(
                  data.step.label,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  data.step.hint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.palette.muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (!_ttsAvailable && _ttsInitStarted)
                  _ttsNotice(context),
                ..._stepChildren(context, data, controller),
                const SizedBox(height: AppSpacing.lg),
                _navigation(context, data, controller),
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
          ),
        ],
      ),
    );
  }

  List<Widget> _stepChildren(
    BuildContext context,
    ListeningSessionState data,
    ListeningSessionController controller,
  ) {
    switch (data.step) {
      case ListeningStep.blind:
        return _blindStep(context, data, controller);
      case ListeningStep.dictation:
        return _dictationStep(context, data, controller);
      case ListeningStep.check:
        return _checkStep(context, data, controller);
      case ListeningStep.classify:
        return _classifyStep(context, data, controller);
      case ListeningStep.shadow:
        return _shadowStep(context, data, controller);
      case ListeningStep.replay:
        return _replayStep(context, data, controller);
    }
  }

  // --- step 1: 盲听 --------------------------------------------------------

  List<Widget> _blindStep(
    BuildContext context,
    ListeningSessionState data,
    ListeningSessionController controller,
  ) {
    return <Widget>[
      _sectionCard(context, data.section),
      const SizedBox(height: AppSpacing.md),
      _playbackControls(context, () => _playAll(data.cues)),
      if (data.hasQuestions) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        ..._questionInputs(context, data, controller),
      ],
    ];
  }

  // --- step 2: 逐句听写 ----------------------------------------------------

  List<Widget> _dictationStep(
    BuildContext context,
    ListeningSessionState data,
    ListeningSessionController controller,
  ) {
    final ListeningCue? cue = data.currentCue;
    if (cue == null) {
      return <Widget>[const Text(AppStrings.listeningEmpty)];
    }
    return <Widget>[
      _cueNavigator(context, data, controller),
      const SizedBox(height: AppSpacing.sm),
      CueTile(
        cue: cue,
        index: data.cueIndex,
        total: data.totalCues,
        showText: false,
        active: true,
        bookmarked: data.isBookmarked(cue.id),
        onPlay: _ttsAvailable ? () => _playCue(cue) : null,
        onToggleBookmark: () => controller.toggleBookmark(cue),
      ),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        controller: _dictation,
        maxLines: 3,
        minLines: 2,
        textInputAction: TextInputAction.done,
        onChanged: (String value) => controller.setDictation(cue.id, value),
        decoration: const InputDecoration(
          hintText: AppStrings.listeningDictationHint,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      _slowToggle(context),
    ];
  }

  // --- step 3: 对照原文 ----------------------------------------------------

  List<Widget> _checkStep(
    BuildContext context,
    ListeningSessionState data,
    ListeningSessionController controller,
  ) {
    return <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: SecondaryButton(
              label: _showTranscript
                  ? AppStrings.listeningHideTranscript
                  : AppStrings.listeningShowTranscript,
              onPressed: () =>
                  setState(() => _showTranscript = !_showTranscript),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SecondaryButton(
              label: _showTranslation
                  ? AppStrings.listeningHideTranslation
                  : AppStrings.listeningShowTranslation,
              onPressed: () =>
                  setState(() => _showTranslation = !_showTranslation),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      for (int i = 0; i < data.cues.length; i++)
        CueTile(
          cue: data.cues[i],
          index: i,
          total: data.totalCues,
          showText: _showTranscript,
          showTranslation: _showTranslation,
          dictation: data.dictationFor(data.cues[i].id),
          bookmarked: data.isBookmarked(data.cues[i].id),
          active: i == data.cueIndex,
          onPlay: _ttsAvailable ? () => _playCue(data.cues[i]) : null,
          onToggleBookmark: () => controller.toggleBookmark(data.cues[i]),
        ),
    ];
  }

  // --- step 4: 错因分类 ----------------------------------------------------

  List<Widget> _classifyStep(
    BuildContext context,
    ListeningSessionState data,
    ListeningSessionController controller,
  ) {
    final ThemeData theme = Theme.of(context);
    if (!data.hasQuestions) {
      return <Widget>[
        const EmptyState(
          icon: Icons.rule_folder_outlined,
          message: AppStrings.listeningEmpty,
        ),
      ];
    }
    if (!data.graded) {
      return <Widget>[
        PrimaryButton(
          label: AppStrings.submit,
          expand: true,
          onPressed: controller.submit,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppStrings.vocabularyPracticeProgress(
            data.answeredCount,
            data.totalQuestions,
          ),
          style: theme.textTheme.caption.copyWith(color: context.palette.muted),
        ),
      ];
    }

    return <Widget>[
      Text(
        AppStrings.vocabularyPracticeResult(data.correctCount, data.totalQuestions),
        style: theme.textTheme.titleSmall,
      ),
      const SizedBox(height: AppSpacing.md),
      for (int i = 0; i < data.questions.length; i++) ...<Widget>[
        _questionResult(context, data, data.questions[i], i + 1),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (data.wrongQuestions.isNotEmpty) ...<Widget>[
        Text(
          AppStrings.vocabularyPracticeProgress(
            data.classifiedCount,
            data.wrongQuestions.length,
          ),
          style: theme.textTheme.caption.copyWith(color: context.palette.muted),
        ),
      ],
    ];
  }

  Widget _questionResult(
    BuildContext context,
    ListeningSessionState data,
    ListeningQuestion question,
    int number,
  ) {
    final ThemeData theme = Theme.of(context);
    final bool wrong = data.resultFor(question.id) == false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ListeningQuestionView(
          question: question,
          number: number,
          value: data.answerFor(question.id),
          textController: question.type.isChoice
              ? null
              : _answerController(question.id, data.answerFor(question.id)),
          readOnly: true,
          result: data.resultFor(question.id),
          onChanged: (_) {},
        ),
        const SizedBox(height: AppSpacing.md),
        ListeningExplanationView(
          question: question,
          isCorrect: data.resultFor(question.id) ?? false,
          userAnswer: data.answerFor(question.id),
          evidenceCue: _evidenceCue(data, question),
        ),
        if (wrong) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.listeningStepClassify,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          ErrorTypeSelector(
            selected: data.errorTypeFor(question.id),
            onSelected: (ListeningErrorType type) =>
                _setErrorType(question, type),
          ),
        ],
      ],
    );
  }

  // --- step 5: 跟读模仿 ----------------------------------------------------

  List<Widget> _shadowStep(
    BuildContext context,
    ListeningSessionState data,
    ListeningSessionController controller,
  ) {
    return <Widget>[
      _playbackControls(context, () => _playAll(data.cues)),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: <Widget>[
          Expanded(
            child: SecondaryButton(
              label: _showTranslation
                  ? AppStrings.listeningHideTranslation
                  : AppStrings.listeningShowTranslation,
              onPressed: () =>
                  setState(() => _showTranslation = !_showTranslation),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      for (int i = 0; i < data.cues.length; i++)
        CueTile(
          cue: data.cues[i],
          index: i,
          total: data.totalCues,
          showText: true,
          showTranslation: _showTranslation,
          bookmarked: data.isBookmarked(data.cues[i].id),
          active: i == data.cueIndex,
          onPlay: _ttsAvailable ? () => _playCue(data.cues[i]) : null,
          onToggleBookmark: () => controller.toggleBookmark(data.cues[i]),
        ),
    ];
  }

  // --- step 6: 整段复听 ----------------------------------------------------

  List<Widget> _replayStep(
    BuildContext context,
    ListeningSessionState data,
    ListeningSessionController controller,
  ) {
    final ThemeData theme = Theme.of(context);
    return <Widget>[
      _playbackControls(context, () => _playAll(data.cues)),
      const SizedBox(height: AppSpacing.lg),
      if (data.hasQuestions) ...<Widget>[
        Text(AppStrings.readingQuestions, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        for (int i = 0; i < data.questions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ListeningQuestionView(
              question: data.questions[i],
              number: i + 1,
              value: data.answerFor(data.questions[i].id),
              textController: data.questions[i].type.isChoice
                  ? null
                  : _answerController(
                      data.questions[i].id,
                      data.answerFor(data.questions[i].id),
                    ),
              readOnly: true,
              result: data.resultFor(data.questions[i].id),
              onChanged: (_) {},
            ),
          ),
        if (data.graded)
          Text(
            AppStrings.vocabularyPracticeResult(
              data.correctCount,
              data.totalQuestions,
            ),
            style: theme.textTheme.titleSmall,
          ),
        const SizedBox(height: AppSpacing.lg),
      ],
      SecondaryButton(
        label: AppStrings.vocabularyPracticeRestart,
        expand: true,
        onPressed: controller.restart,
      ),
      if (data.saved) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppStrings.settingsSaved,
          style: theme.textTheme.caption.copyWith(
            color: context.palette.success,
          ),
        ),
      ],
    ];
  }

  // --- shared pieces ------------------------------------------------------

  Widget _sectionCard(BuildContext context, ListeningSection section) {
    final ThemeData theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(section.partLabel, style: theme.textTheme.titleSmall),
              const Spacer(),
              if (section.difficulty != null)
                Text(
                  AppStrings.vocabularyDifficultyLabel(section.difficulty!),
                  style: theme.textTheme.caption.copyWith(
                    color: context.palette.muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(section.title, style: theme.textTheme.titleMedium),
          if (section.scene != null && section.scene!.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              section.scene!,
              style: theme.textTheme.caption.copyWith(
                color: context.palette.muted,
              ),
            ),
          ],
          if (section.overview != null && section.overview!.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(section.overview!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Widget _ttsNotice(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Icon(Icons.volume_off_outlined, size: 18, color: context.palette.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              AppStrings.listeningTtsUnavailable,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.palette.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playbackControls(BuildContext context, VoidCallback onPlayAll) {
    return Row(
      children: <Widget>[
        Expanded(
          child: PrimaryButton(
            label: AppStrings.listeningPlayAll,
            icon: Icons.play_arrow,
            onPressed: _ttsAvailable ? onPlayAll : null,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _slowToggle(context),
      ],
    );
  }

  Widget _slowToggle(BuildContext context) {
    return ChoiceChip(
      label: const Text(AppStrings.listeningPlaySlow),
      selected: _slow,
      onSelected: (_) => setState(() => _slow = !_slow),
    );
  }

  Widget _cueNavigator(
    BuildContext context,
    ListeningSessionState data,
    ListeningSessionController controller,
  ) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: data.cueIndex > 0 ? controller.previousCue : null,
        ),
        Expanded(
          child: Text(
            AppStrings.vocabularyPracticeProgress(
              data.cueIndex + 1,
              data.totalCues,
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: data.cueIndex < data.totalCues - 1
              ? controller.nextCue
              : null,
        ),
      ],
    );
  }

  List<Widget> _questionInputs(
    BuildContext context,
    ListeningSessionState data,
    ListeningSessionController controller,
  ) {
    return <Widget>[
      Text(AppStrings.readingQuestions, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AppSpacing.md),
      for (int i = 0; i < data.questions.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: ListeningQuestionView(
            question: data.questions[i],
            number: i + 1,
            value: data.answerFor(data.questions[i].id),
            textController: data.questions[i].type.isChoice
                ? null
                : _answerController(
                    data.questions[i].id,
                    data.answerFor(data.questions[i].id),
                  ),
            readOnly: data.results.isNotEmpty,
            result: data.resultFor(data.questions[i].id),
            onChanged: (String value) =>
                controller.answer(data.questions[i].id, value),
          ),
        ),
    ];
  }

  Widget _navigation(
    BuildContext context,
    ListeningSessionState data,
    ListeningSessionController controller,
  ) {
    final bool isLast = data.step == ListeningStep.values.last;
    return Row(
      children: <Widget>[
        Expanded(
          child: SecondaryButton(
            label: AppStrings.previous,
            expand: true,
            onPressed: data.step.index > 0 ? controller.previousStep : null,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: isLast
              ? PrimaryButton(
                  label: AppStrings.done,
                  expand: true,
                  onPressed: () => _exit(context, controller),
                )
              : PrimaryButton(
                  label: AppStrings.next,
                  expand: true,
                  onPressed: controller.nextStep,
                ),
        ),
      ],
    );
  }

  // --- helpers ------------------------------------------------------------

  ListeningCue? _evidenceCue(
    ListeningSessionState data,
    ListeningQuestion question,
  ) {
    final int? cueId = question.evidenceCueId;
    if (cueId == null) {
      return null;
    }
    return data.cueById(cueId);
  }

  void _setErrorType(ListeningQuestion question, ListeningErrorType type) {
    ref
        .read(listeningSessionControllerProvider(widget.sectionId).notifier)
        .setErrorType(question.id, type);
  }

  TextEditingController _answerController(int questionId, String value) {
    final TextEditingController? existing = _answerControllers[questionId];
    if (existing != null) {
      return existing;
    }
    final TextEditingController created = TextEditingController(text: value);
    _answerControllers[questionId] = created;
    return created;
  }

  void _onSpeakingChanged(bool speaking) {
    if (!mounted) {
      return;
    }
    setState(() => _speaking = speaking);
  }

  void _ensureTts(String? accent) {
    if (_ttsInitStarted) {
      return;
    }
    _ttsInitStarted = true;
    _tts.beginSection();
    _tts.init(accent: accent).then((bool available) {
      if (mounted) {
        setState(() => _ttsAvailable = available);
      }
    });
  }

  void _syncDictation(ListeningSessionState data) {
    final ListeningCue? cue = data.currentCue;
    if (cue == null || cue.id == _lastCueId) {
      return;
    }
    _lastCueId = cue.id;
    final String value = data.dictationFor(cue.id);
    _dictation.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Future<void> _playCue(ListeningCue cue) => _tts.speakCue(cue, slow: _slow);

  Future<void> _playAll(List<ListeningCue> cues) =>
      _tts.speakAll(cues, slow: _slow);

  Future<void> _stop() => _tts.stop();

  Future<void> _exit(
    BuildContext context,
    ListeningSessionController controller,
  ) async {
    await _tts.stop();
    await controller.finish();
    if (context.mounted) {
      context.go(AppRoutes.listening);
    }
  }
}
