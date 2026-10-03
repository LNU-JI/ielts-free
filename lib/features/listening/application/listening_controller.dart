/// Listening intensive-listening session (the "精听" loop).
///
/// Runs one section through the six-step loop the method prescribes:
///
/// 1. [ListeningStep.blind]   盲听 — whole-section playback, no transcript;
/// 2. [ListeningStep.dictation] 逐句听写 — replay one cue, write it down;
/// 3. [ListeningStep.check]   对照原文 — compare against text / translation;
/// 4. [ListeningStep.classify] 错因分类 — tag every miss with one of the five
///    [ListeningErrorType]s (the step that actually changes the next round);
/// 5. [ListeningStep.shadow]  跟读模仿 — replay and shadow each cue;
/// 6. [ListeningStep.replay]  整段复听 — full replay, then finish.
///
/// Leaving the session writes the classified misses into `listening_error_log`
/// and the bookmarked sentences into `sentence_book`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/enums/listening_error_type.dart';
import 'package:ielts_free/core/models/listening_cue.dart';
import 'package:ielts_free/core/models/listening_error.dart';
import 'package:ielts_free/core/models/listening_question.dart';
import 'package:ielts_free/core/models/listening_section.dart';
import 'package:ielts_free/core/models/sentence_entry.dart';
import 'package:ielts_free/core/providers/listening_provider.dart';
import 'package:ielts_free/core/providers/refresh_provider.dart';
import 'package:ielts_free/core/providers/service_providers.dart';
import 'package:ielts_free/core/storage/repositories/listening_repository.dart';
import 'package:ielts_free/core/utils/logger.dart';
import 'package:ielts_free/core/utils/text_utils.dart';

/// The six stages of the intensive-listening loop.
enum ListeningStep {
  /// 盲听 — listen for gist, no transcript.
  blind,

  /// 逐句听写 — sentence-by-sentence dictation.
  dictation,

  /// 对照原文 — compare the dictation with the transcript.
  check,

  /// 错因分类 — classify every miss.
  classify,

  /// 跟读模仿 — shadow each sentence.
  shadow,

  /// 整段复听 — full replay and wrap-up.
  replay,
}

/// Chinese name of a step (from the shared copy deck).
extension ListeningStepX on ListeningStep {
  /// The step's short label.
  String get label => switch (this) {
        ListeningStep.blind => AppStrings.listeningStepBlind,
        ListeningStep.dictation => AppStrings.listeningStepDictation,
        ListeningStep.check => AppStrings.listeningStepCheck,
        ListeningStep.classify => AppStrings.listeningStepClassify,
        ListeningStep.shadow => AppStrings.listeningStepShadow,
        ListeningStep.replay => AppStrings.listeningStepReplay,
      };

  /// The step's one-line guidance.
  String get hint => switch (this) {
        ListeningStep.blind => AppStrings.listeningStepBlindHint,
        ListeningStep.dictation => AppStrings.listeningStepDictationHint,
        ListeningStep.check => AppStrings.listeningStepCheckHint,
        ListeningStep.classify => AppStrings.listeningStepClassifyHint,
        ListeningStep.shadow => AppStrings.listeningStepShadowHint,
        ListeningStep.replay => AppStrings.listeningStepReplayHint,
      };

  /// 1-based position in the loop.
  int get position => index + 1;
}

/// Immutable state of one intensive-listening session.
@immutable
class ListeningSessionState {
  const ListeningSessionState({
    required this.section,
    this.cues = const <ListeningCue>[],
    this.questions = const <ListeningQuestion>[],
    this.step = ListeningStep.blind,
    this.cueIndex = 0,
    this.dictations = const <int, String>{},
    this.answers = const <int, String>{},
    this.results = const <int, bool>{},
    this.errorTypes = const <int, ListeningErrorType>{},
    this.bookmarked = const <int>{},
    this.submitting = false,
    this.saved = false,
    this.error,
  });

  /// The section being practised.
  final ListeningSection section;

  /// The spoken lines, ordered.
  final List<ListeningCue> cues;

  /// The section's questions.
  final List<ListeningQuestion> questions;

  /// The step currently shown.
  final ListeningStep step;

  /// The cue shown in the dictation / check / shadow steps.
  final int cueIndex;

  /// Dictation text keyed by cue id.
  final Map<int, String> dictations;

  /// Answers keyed by question id.
  final Map<int, String> answers;

  /// Grading results keyed by question id (populated after [submit]).
  final Map<int, bool> results;

  /// Chosen error cause keyed by question id.
  final Map<int, ListeningErrorType> errorTypes;

  /// Cue ids the learner bookmarked in this session.
  final Set<int> bookmarked;

  /// Whether grading is in flight.
  final bool submitting;

  /// Whether the misses / bookmarks have been flushed to the user database.
  final bool saved;

  /// A user-facing error, or `null`.
  final String? error;

  /// Number of cues.
  int get totalCues => cues.length;

  /// Number of questions.
  int get totalQuestions => questions.length;

  /// The cue currently shown, or `null`.
  ListeningCue? get currentCue =>
      cueIndex >= 0 && cueIndex < cues.length ? cues[cueIndex] : null;

  /// Whether the session has questions at all.
  bool get hasQuestions => questions.isNotEmpty;

  /// Whether grading has run.
  bool get graded => results.isNotEmpty || questions.isEmpty;

  /// Questions answered incorrectly (after grading).
  List<ListeningQuestion> get wrongQuestions => questions
      .where((ListeningQuestion q) => results[q.id] == false)
      .toList(growable: false);

  /// Number of questions answered correctly.
  int get correctCount => results.values.where((bool v) => v).length;

  /// Number of questions with a non-empty answer.
  int get answeredCount => questions
      .where((ListeningQuestion q) => (answers[q.id] ?? '').trim().isNotEmpty)
      .length;

  /// Number of misses already classified.
  int get classifiedCount => wrongQuestions
      .where((ListeningQuestion q) => errorTypes[q.id] != null)
      .length;

  /// Whether every miss has a cause.
  bool get allMissesClassified {
    final List<ListeningQuestion> wrong = wrongQuestions;
    return wrong.isEmpty ||
        wrong.every((ListeningQuestion q) => errorTypes[q.id] != null);
  }

  /// Number of bookmarked cues.
  int get bookmarkedCount => bookmarked.length;

  /// The dictation for [cueId], or `''`.
  String dictationFor(int cueId) => dictations[cueId] ?? '';

  /// The answer for [questionId], or `''`.
  String answerFor(int questionId) => answers[questionId] ?? '';

  /// The result for [questionId], or `null` before grading.
  bool? resultFor(int questionId) => results[questionId];

  /// The chosen cause for [questionId], or `null`.
  ListeningErrorType? errorTypeFor(int questionId) => errorTypes[questionId];

  /// Whether [cueId] is bookmarked.
  bool isBookmarked(int cueId) => bookmarked.contains(cueId);

  /// The cue with [id], or `null`.
  ListeningCue? cueById(int id) {
    for (final ListeningCue cue in cues) {
      if (cue.id == id) {
        return cue;
      }
    }
    return null;
  }

  /// Returns a copy with the given fields replaced.
  ListeningSessionState copyWith({
    List<ListeningCue>? cues,
    List<ListeningQuestion>? questions,
    ListeningStep? step,
    int? cueIndex,
    Map<int, String>? dictations,
    Map<int, String>? answers,
    Map<int, bool>? results,
    Map<int, ListeningErrorType>? errorTypes,
    Set<int>? bookmarked,
    bool? submitting,
    bool? saved,
    String? error,
    bool clearError = false,
  }) {
    return ListeningSessionState(
      section: section,
      cues: cues ?? this.cues,
      questions: questions ?? this.questions,
      step: step ?? this.step,
      cueIndex: cueIndex ?? this.cueIndex,
      dictations: dictations ?? this.dictations,
      answers: answers ?? this.answers,
      results: results ?? this.results,
      errorTypes: errorTypes ?? this.errorTypes,
      bookmarked: bookmarked ?? this.bookmarked,
      submitting: submitting ?? this.submitting,
      saved: saved ?? this.saved,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for one intensive-listening session, keyed by section id.
class ListeningSessionController
    extends FamilyAsyncNotifier<ListeningSessionState, int> {
  /// Question ids already written to `listening_error_log` this session.
  final Set<int> _recordedErrors = <int>{};

  @override
  Future<ListeningSessionState> build(int sectionId) async {
    final ListeningRepository repository =
        await ref.read(listeningRepositoryProvider.future);
    final ListeningSectionDetail? detail =
        await repository.sectionDetail(sectionId);
    if (detail == null) {
      throw const NotFoundException('LISTENING_NOT_FOUND', '未找到该听力素材。');
    }
    return ListeningSessionState(
      section: detail.section,
      cues: detail.cues,
      questions: detail.questions,
    );
  }

  // --- step navigation ----------------------------------------------------

  /// Jumps to [step].
  void setStep(ListeningStep step) {
    final ListeningSessionState? current = state.valueOrNull;
    if (current == null || current.step == step) {
      return;
    }
    state = AsyncData<ListeningSessionState>(
      current.copyWith(step: step, clearError: true),
    );
  }

  /// Advances one step (no-op on the last step).
  void nextStep() {
    final ListeningSessionState? current = state.valueOrNull;
    if (current == null || current.step == ListeningStep.values.last) {
      return;
    }
    setStep(ListeningStep.values[current.step.index + 1]);
  }

  /// Goes back one step (no-op on the first step).
  void previousStep() {
    final ListeningSessionState? current = state.valueOrNull;
    if (current == null || current.step.index == 0) {
      return;
    }
    setStep(ListeningStep.values[current.step.index - 1]);
  }

  // --- cue navigation -----------------------------------------------------

  /// Moves the cue cursor to [index] (clamped to range).
  void goToCue(int index) {
    final ListeningSessionState? current = state.valueOrNull;
    if (current == null || current.cues.isEmpty) {
      return;
    }
    final int clamped = index.clamp(0, current.cues.length - 1).toInt();
    state = AsyncData<ListeningSessionState>(current.copyWith(cueIndex: clamped));
  }

  /// Moves to the next cue.
  void nextCue() => goToCue((state.valueOrNull?.cueIndex ?? 0) + 1);

  /// Moves to the previous cue.
  void previousCue() => goToCue((state.valueOrNull?.cueIndex ?? 0) - 1);

  // --- dictation & answers ------------------------------------------------

  /// Records the dictation for [cueId].
  void setDictation(int cueId, String value) {
    final ListeningSessionState? current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final Map<int, String> dictations = Map<int, String>.of(current.dictations)
      ..[cueId] = value;
    state = AsyncData<ListeningSessionState>(current.copyWith(dictations: dictations));
  }

  /// Records the answer for [questionId].
  void answer(int questionId, String value) {
    final ListeningSessionState? current = state.valueOrNull;
    if (current == null || current.results.isNotEmpty) {
      return;
    }
    final Map<int, String> answers = Map<int, String>.of(current.answers)
      ..[questionId] = value;
    state = AsyncData<ListeningSessionState>(current.copyWith(answers: answers));
  }

  /// Grades every question with the accepted-answer set.
  void submit() {
    final ListeningSessionState? current = state.valueOrNull;
    if (current == null || current.results.isNotEmpty) {
      return;
    }
    final Map<int, bool> results = <int, bool>{};
    for (final ListeningQuestion question in current.questions) {
      results[question.id] = _gradeQuestion(
        question,
        current.answerFor(question.id),
      );
    }
    state = AsyncData<ListeningSessionState>(
      current.copyWith(results: results, clearError: true),
    );
  }

  /// Records the chosen cause for a missed [questionId].
  void setErrorType(int questionId, ListeningErrorType type) {
    final ListeningSessionState? current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final Map<int, ListeningErrorType> types =
        Map<int, ListeningErrorType>.of(current.errorTypes)
          ..[questionId] = type;
    state = AsyncData<ListeningSessionState>(current.copyWith(errorTypes: types));
  }

  // --- sentence book ------------------------------------------------------

  /// Adds or removes [cue] from the sentence book (persisted immediately).
  Future<void> toggleBookmark(ListeningCue cue) async {
    final ListeningSessionState? current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final bool wasBookmarked = current.isBookmarked(cue.id);
    final Set<int> bookmarked = Set<int>.of(current.bookmarked);
    if (wasBookmarked) {
      bookmarked.remove(cue.id);
    } else {
      bookmarked.add(cue.id);
    }
    state = AsyncData<ListeningSessionState>(current.copyWith(bookmarked: bookmarked));

    if (wasBookmarked) {
      // Removal is not exposed by the repository in this module; the bookmark
      // is simply dropped from the session. Persisted rows are managed on the
      // sentence-book screen.
      return;
    }
    await _persistBookmark(cue);
  }

  // --- finish -------------------------------------------------------------

  /// Flushes the classified misses and the bookmarked sentences.
  ///
  /// Idempotent: a second call only writes what is still missing.
  Future<void> finish() async {
    final ListeningSessionState? current = state.valueOrNull;
    if (current == null) {
      return;
    }
    try {
      final ListeningRepository repository =
          await ref.read(listeningRepositoryProvider.future);
      final DateTime now = ref.read(clockProvider).now();

      for (final ListeningQuestion question in current.wrongQuestions) {
        final ListeningErrorType? type = current.errorTypeFor(question.id);
        if (type == null || _recordedErrors.contains(question.id)) {
          continue;
        }
        await repository.recordError(
          ListeningError(
            userId: AppConstants.localUserId,
            sectionId: current.section.id,
            questionId: question.id,
            cueId: question.evidenceCueId,
            errorType: type,
            createdAt: now,
          ),
        );
        _recordedErrors.add(question.id);
      }

      for (final int cueId in current.bookmarked) {
        final ListeningCue? cue = current.cueById(cueId);
        if (cue != null) {
          await _persistBookmark(cue);
        }
      }

      final ListeningSessionState? latest = state.valueOrNull;
      if (latest != null) {
        state = AsyncData<ListeningSessionState>(
          latest.copyWith(saved: true, clearError: true),
        );
      }
      notifyDataChanged(ref);
    } on Object catch (error, stackTrace) {
      appLogger.warning('Listening finish failed.', error, stackTrace);
      final ListeningSessionState? latest = state.valueOrNull;
      if (latest != null) {
        state = AsyncData<ListeningSessionState>(
          latest.copyWith(error: failureFromException(error).message),
        );
      }
    }
  }

  /// Starts a fresh session over the same section.
  void restart() {
    final ListeningSessionState? current = state.valueOrNull;
    if (current == null) {
      return;
    }
    _recordedErrors.clear();
    state = AsyncData<ListeningSessionState>(
      ListeningSessionState(
        section: current.section,
        cues: current.cues,
        questions: current.questions,
      ),
    );
  }

  // --- internals ----------------------------------------------------------

  Future<void> _persistBookmark(ListeningCue cue) async {
    try {
      final ListeningRepository repository =
          await ref.read(listeningRepositoryProvider.future);
      await repository.bookmarkSentence(
        SentenceEntry(
          userId: AppConstants.localUserId,
          sourceType: 'LISTENING',
          sourceId: cue.id,
          sectionId: cue.sectionId,
          text: cue.text,
          translation: cue.translation,
          createdAt: ref.read(clockProvider).now(),
        ),
      );
      notifyDataChanged(ref);
    } on Object catch (error, stackTrace) {
      appLogger.warning('Sentence bookmark failed.', error, stackTrace);
      final ListeningSessionState? latest = state.valueOrNull;
      if (latest != null) {
        final Set<int> bookmarked = Set<int>.of(latest.bookmarked)..remove(cue.id);
        state = AsyncData<ListeningSessionState>(
          latest.copyWith(
            bookmarked: bookmarked,
            error: failureFromException(error).message,
          ),
        );
      }
    }
  }

  bool _gradeQuestion(ListeningQuestion question, String userAnswer) {
    final String value = userAnswer.trim();
    if (value.isEmpty) {
      return false;
    }
    for (final String accepted in question.acceptedAnswers) {
      if (_matches(question, accepted, value)) {
        return true;
      }
    }
    return false;
  }

  bool _matches(ListeningQuestion question, String expected, String actual) {
    if (question.type.isChoice && question.options.isNotEmpty) {
      return _canonicalChoice(question, expected) ==
          _canonicalChoice(question, actual);
    }
    if (TextUtils.answersMatch(expected, actual)) {
      return true;
    }
    if (TextUtils.answersMatchLoose(expected, actual)) {
      return true;
    }
    // Gap-fill answers accept an omitted leading article (`the library` ≈
    // `library`), matching the grading note in ARCHITECTURE §5.
    if (question.type.isCompletion) {
      final String e = TextUtils.normalizeForCompletion(expected);
      final String a = TextUtils.normalizeForCompletion(actual);
      return e.isNotEmpty && e == a;
    }
    return false;
  }

  /// Resolves a label (`B`) or its option text to one canonical key, so either
  /// form of a multiple-choice answer grades correctly.
  String _canonicalChoice(ListeningQuestion question, String value) {
    final String norm = TextUtils.normalize(value);
    for (final ListeningOption option in question.options) {
      final String label = TextUtils.normalize(option.label);
      if (label == norm) {
        return 'label:$label';
      }
      if (TextUtils.normalize(option.content) == norm) {
        return 'label:$label';
      }
    }
    return 'text:$norm';
  }
}

/// Provider for one intensive-listening session, keyed by section id.
final AsyncNotifierProviderFamily<ListeningSessionController,
        ListeningSessionState, int> listeningSessionControllerProvider =
    AsyncNotifierProvider.family<ListeningSessionController,
        ListeningSessionState, int>(ListeningSessionController.new);
