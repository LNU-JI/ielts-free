/// Speaking session state machine (PRD §4.6 / BRIEF §20).
///
/// Runs one topic question by question:
///
/// * **Part 1 / Part 3** — ask → timed answer → stop → replay → self-rating.
/// * **Part 2** — show the cue card → preparation countdown (notes allowed) →
///   answer countdown → stop → replay → self-rating.
///
/// **No AI scoring** — that is a deliberate product red line. The five-item
/// self-assessment checklist is its offline stand-in; the answers are persisted
/// to `speaking_attempts` with the checklist encoded into `self_rating` as JSON.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/enums/speaking_part.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/models/speaking_attempt.dart';
import 'package:ielts_free/core/models/speaking_question.dart';
import 'package:ielts_free/core/models/speaking_topic.dart';
import 'package:ielts_free/core/providers/refresh_provider.dart';
import 'package:ielts_free/core/providers/service_providers.dart';
import 'package:ielts_free/core/providers/speaking_provider.dart';
import 'package:ielts_free/core/storage/repositories/speaking_repository.dart';
import 'package:ielts_free/core/utils/logger.dart';
import 'package:ielts_free/features/speaking/application/speaking_audio_player.dart';
import 'package:ielts_free/features/speaking/application/speaking_recorder.dart';

/// Which stage of one question the learner is in.
enum SpeakingPhase {
  /// Not started: waiting for "开始准备" / "开始作答".
  ready,

  /// Part 2 preparation countdown (notes allowed).
  prep,

  /// Answer countdown, recording when the microphone is available.
  speaking,

  /// Stopped: replay, model answer and the self-assessment checklist.
  review,

  /// Every question of the topic has been answered and saved.
  finished,
}

/// The five items of the self-assessment checklist.
enum SpeakingRatingItem { fluency, clarity, pace, content, grammar }

/// The five-item self-assessment, each scored 1–5, plus an optional note.
@immutable
class SpeakingSelfRating {
  const SpeakingSelfRating({
    this.fluency = 0,
    this.clarity = 0,
    this.pace = 0,
    this.content = 0,
    this.grammar = 0,
    this.note = '',
  });

  /// Highest score per item.
  static const int maxScore = 5;

  /// 流畅度.
  final int fluency;

  /// 清晰度.
  final int clarity;

  /// 节奏.
  final int pace;

  /// 内容.
  final int content;

  /// 语法.
  final int grammar;

  /// Free-form note saved alongside the scores.
  final String note;

  /// Whether all five items have been scored.
  bool get isComplete =>
      fluency > 0 && clarity > 0 && pace > 0 && content > 0 && grammar > 0;

  /// Returns a copy with the given fields replaced.
  SpeakingSelfRating copyWith({
    int? fluency,
    int? clarity,
    int? pace,
    int? content,
    int? grammar,
    String? note,
  }) {
    return SpeakingSelfRating(
      fluency: fluency ?? this.fluency,
      clarity: clarity ?? this.clarity,
      pace: pace ?? this.pace,
      content: content ?? this.content,
      grammar: grammar ?? this.grammar,
      note: note ?? this.note,
    );
  }

  /// Serialises to the JSON object stored in `speaking_attempts.self_rating`.
  Map<String, Object?> toJson() => <String, Object?>{
        'fluency': fluency,
        'clarity': clarity,
        'pace': pace,
        'content': content,
        'grammar': grammar,
        'note': note,
      };
}

/// Immutable speaking-session state.
@immutable
class SpeakingSessionState {
  const SpeakingSessionState({
    required this.topic,
    this.questions = const <SpeakingQuestion>[],
    this.currentIndex = 0,
    this.phase = SpeakingPhase.ready,
    this.remainingSeconds = 0,
    this.totalSeconds = 0,
    this.spokenSeconds = 0,
    this.recordingPath,
    this.micGranted,
    this.notes = '',
    this.ratings = const <int, SpeakingSelfRating>{},
    this.savedQuestionIds = const <int>{},
    this.timedOut = false,
    this.busy = false,
    this.error,
  });

  /// The topic being practised.
  final SpeakingTopic topic;

  /// The topic's questions, in examiner order.
  final List<SpeakingQuestion> questions;

  /// The question currently shown.
  final int currentIndex;

  /// Which stage of the current question the learner is in.
  final SpeakingPhase phase;

  /// Seconds left in the active countdown.
  final int remainingSeconds;

  /// Total seconds of the active countdown.
  final int totalSeconds;

  /// Seconds actually spoken for the current question.
  final int spokenSeconds;

  /// Local path of the current recording, when one was kept.
  final String? recordingPath;

  /// Whether the microphone permission is granted (`null` before it is asked).
  final bool? micGranted;

  /// Preparation notes for the current question (Part 2).
  final String notes;

  /// Self-assessments keyed by question id.
  final Map<int, SpeakingSelfRating> ratings;

  /// Ids of the questions already saved to `speaking_attempts`.
  final Set<int> savedQuestionIds;

  /// Whether the last answer ran out of time instead of being stopped.
  final bool timedOut;

  /// Whether a save is in flight.
  final bool busy;

  /// A user-facing error, or `null`.
  final String? error;

  /// Number of questions.
  int get total => questions.length;

  /// The question currently shown, or `null`.
  SpeakingQuestion? get current =>
      currentIndex >= 0 && currentIndex < questions.length
          ? questions[currentIndex]
          : null;

  /// Whether the current question is the last one.
  bool get isLast => total == 0 || currentIndex >= total - 1;

  /// The self-assessment of the current question, or `null`.
  SpeakingSelfRating? get currentRating {
    final SpeakingQuestion? question = current;
    return question == null ? null : ratings[question.id];
  }

  /// Whether the current question's checklist is complete.
  bool get canSave => currentRating?.isComplete ?? false;

  /// Whether the current question needs a preparation phase (Part 2).
  bool get needsPrep =>
      topic.part == SpeakingPart.part2 && topic.effectivePrepSeconds > 0;

  /// Whether the current question has already been saved.
  bool get currentSaved {
    final SpeakingQuestion? question = current;
    return question != null && savedQuestionIds.contains(question.id);
  }

  /// Number of questions saved so far.
  int get savedCount => savedQuestionIds.length;

  /// Fraction of the topic completed in `[0, 1]`.
  double get progress => total == 0 ? 0 : savedCount / total;

  /// Fraction of the active countdown remaining in `[0, 1]`.
  double get countdownProgress =>
      totalSeconds <= 0 ? 0 : remainingSeconds / totalSeconds;

  /// Returns a copy with the given fields replaced.
  SpeakingSessionState copyWith({
    int? currentIndex,
    SpeakingPhase? phase,
    int? remainingSeconds,
    int? totalSeconds,
    int? spokenSeconds,
    String? recordingPath,
    bool clearRecordingPath = false,
    bool? micGranted,
    String? notes,
    Map<int, SpeakingSelfRating>? ratings,
    Set<int>? savedQuestionIds,
    bool? timedOut,
    bool? busy,
    String? error,
    bool clearError = false,
  }) {
    return SpeakingSessionState(
      topic: topic,
      questions: questions,
      currentIndex: currentIndex ?? this.currentIndex,
      phase: phase ?? this.phase,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      spokenSeconds: spokenSeconds ?? this.spokenSeconds,
      recordingPath:
          clearRecordingPath ? null : (recordingPath ?? this.recordingPath),
      micGranted: micGranted ?? this.micGranted,
      notes: notes ?? this.notes,
      ratings: ratings ?? this.ratings,
      savedQuestionIds: savedQuestionIds ?? this.savedQuestionIds,
      timedOut: timedOut ?? this.timedOut,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for one speaking topic.
///
/// `autoDispose` matters here: leaving the page must release the microphone, and
/// disposal is what stops the recorder.
class SpeakingSessionController
    extends AutoDisposeFamilyAsyncNotifier<SpeakingSessionState, int> {
  Timer? _ticker;
  SpeakingRecorder? _recorder;
  bool _alive = true;

  @override
  Future<SpeakingSessionState> build(int topicId) async {
    _alive = true;
    ref.onDispose(() {
      _alive = false;
      _ticker?.cancel();
      _ticker = null;
      final SpeakingRecorder? recorder = _recorder;
      _recorder = null;
      if (recorder != null) {
        unawaited(_releaseRecorder(recorder));
      }
    });

    final SpeakingRepository repository =
        await ref.read(speakingRepositoryProvider.future);
    final SpeakingTopic? topic = await repository.topicDetail(topicId);
    if (topic == null) {
      throw const NotFoundException('SPEAKING_NOT_FOUND', '未找到该口语话题。');
    }

    final SpeakingRecorder recorder =
        ref.read(speakingRecorderFactoryProvider)();
    _recorder = recorder;

    bool? micGranted;
    try {
      micGranted = await recorder.hasPermission();
    } on Object catch (error, stackTrace) {
      appLogger.warning('Microphone permission check failed.', error, stackTrace);
      micGranted = false;
    }

    return SpeakingSessionState(
      topic: topic,
      questions: topic.questions,
      micGranted: micGranted,
    );
  }

  // --- flow ---------------------------------------------------------------

  /// Starts the current question: preparation first for Part 2, otherwise
  /// straight into the answer.
  Future<void> start() async {
    final SpeakingSessionState? current = state.valueOrNull;
    if (current == null || current.phase != SpeakingPhase.ready) {
      return;
    }
    if (current.needsPrep) {
      _beginPrep(current);
      return;
    }
    await _beginSpeaking(current);
  }

  /// Skips the preparation phase and starts answering immediately.
  Future<void> skipPrep() async {
    final SpeakingSessionState? current = state.valueOrNull;
    if (current == null || current.phase != SpeakingPhase.prep) {
      return;
    }
    await _beginSpeaking(current);
  }

  /// Stops the answer early (the countdown otherwise stops it at zero).
  Future<void> stop() async {
    final SpeakingSessionState? current = state.valueOrNull;
    if (current == null || current.phase != SpeakingPhase.speaking) {
      return;
    }
    await _finishSpeaking(current);
  }

  /// Re-opens the current recording with the platform's media handler.
  Future<void> replay() async {
    final SpeakingSessionState? current = state.valueOrNull;
    final String? path = current?.recordingPath;
    if (path == null) {
      return;
    }
    await ref.read(speakingAudioPlayerProvider).play(path);
  }

  /// Updates the preparation notes of the current question.
  void setNotes(String value) {
    final SpeakingSessionState? current = state.valueOrNull;
    if (current == null) {
      return;
    }
    state = AsyncData<SpeakingSessionState>(current.copyWith(notes: value));
  }

  /// Scores one item of the current question's checklist.
  void rate({
    int? fluency,
    int? clarity,
    int? pace,
    int? content,
    int? grammar,
  }) {
    final SpeakingSessionState? current = state.valueOrNull;
    final SpeakingQuestion? question = current?.current;
    if (current == null || question == null) {
      return;
    }
    final SpeakingSelfRating rating =
        (current.ratings[question.id] ?? const SpeakingSelfRating()).copyWith(
      fluency: fluency,
      clarity: clarity,
      pace: pace,
      content: content,
      grammar: grammar,
    );
    final Map<int, SpeakingSelfRating> ratings =
        Map<int, SpeakingSelfRating>.of(current.ratings)
          ..[question.id] = rating;
    state = AsyncData<SpeakingSessionState>(current.copyWith(ratings: ratings));
  }

  /// Scores one checklist [item] of the current question.
  void rateItem(SpeakingRatingItem item, int score) {
    switch (item) {
      case SpeakingRatingItem.fluency:
        rate(fluency: score);
      case SpeakingRatingItem.clarity:
        rate(clarity: score);
      case SpeakingRatingItem.pace:
        rate(pace: score);
      case SpeakingRatingItem.content:
        rate(content: score);
      case SpeakingRatingItem.grammar:
        rate(grammar: score);
    }
  }

  /// Updates the free-form note attached to the current self-assessment.
  void setRatingNote(String value) {
    final SpeakingSessionState? current = state.valueOrNull;
    final SpeakingQuestion? question = current?.current;
    if (current == null || question == null) {
      return;
    }
    final SpeakingSelfRating rating =
        (current.ratings[question.id] ?? const SpeakingSelfRating())
            .copyWith(note: value);
    final Map<int, SpeakingSelfRating> ratings =
        Map<int, SpeakingSelfRating>.of(current.ratings)
          ..[question.id] = rating;
    state = AsyncData<SpeakingSessionState>(current.copyWith(ratings: ratings));
  }

  /// Persists the current question's attempt and moves to the next question.
  Future<void> saveRating() async {
    final SpeakingSessionState? current = state.valueOrNull;
    final SpeakingQuestion? question = current?.current;
    final SpeakingSelfRating? rating = current?.currentRating;
    if (current == null ||
        question == null ||
        rating == null ||
        !rating.isComplete ||
        current.busy) {
      return;
    }

    state = AsyncData<SpeakingSessionState>(
      current.copyWith(busy: true, clearError: true),
    );
    try {
      final SpeakingRepository repository =
          await ref.read(speakingRepositoryProvider.future);
      await repository.recordAttempt(
        SpeakingAttempt(
          userId: AppConstants.localUserId,
          questionId: question.id,
          topicId: current.topic.id,
          part: current.topic.part,
          durationSec: current.spokenSeconds,
          audioPath: current.recordingPath,
          selfRating: encodeMap(rating.toJson()),
          createdAt: ref.read(clockProvider).now().toUtc(),
        ),
      );

      final Set<int> saved = Set<int>.of(current.savedQuestionIds)
        ..add(question.id);
      final bool last = current.isLast;
      final SpeakingSessionState updated = _resetFor(
        current.copyWith(
          savedQuestionIds: saved,
          busy: false,
          clearError: true,
        ),
        last ? current.currentIndex : current.currentIndex + 1,
        finished: last,
      );
      state = AsyncData<SpeakingSessionState>(updated);
      _ticker?.cancel();
      _ticker = null;
      notifyDataChanged(ref);
    } on Object catch (error, stackTrace) {
      appLogger.warning('Speaking attempt save failed.', error, stackTrace);
      state = AsyncData<SpeakingSessionState>(
        current.copyWith(
          busy: false,
          error: failureFromException(error).message,
        ),
      );
    }
  }

  /// Moves to [index], resetting the per-question flow but keeping the scores.
  ///
  /// Stops any in-flight recording first, so jumping between questions never
  /// leaves the microphone open.
  Future<void> goTo(int index) async {
    final SpeakingSessionState? current = state.valueOrNull;
    if (current == null || index < 0 || index >= current.questions.length) {
      return;
    }
    _ticker?.cancel();
    _ticker = null;
    if (current.phase == SpeakingPhase.speaking && current.recordingPath != null) {
      await _stopRecorderQuietly();
    }
    final SpeakingSessionState latest = state.valueOrNull ?? current;
    state = AsyncData<SpeakingSessionState>(_resetFor(latest, index));
  }

  /// Moves to the next question.
  Future<void> next() => goTo((state.valueOrNull?.currentIndex ?? 0) + 1);

  /// Moves to the previous question.
  Future<void> previous() => goTo((state.valueOrNull?.currentIndex ?? 0) - 1);

  /// Starts the topic over from the first question.
  Future<void> restart() async {
    final SpeakingSessionState? current = state.valueOrNull;
    if (current == null) {
      return;
    }
    _ticker?.cancel();
    _ticker = null;
    if (current.phase == SpeakingPhase.speaking && current.recordingPath != null) {
      await _stopRecorderQuietly();
    }
    final SpeakingSessionState latest = state.valueOrNull ?? current;
    state = AsyncData<SpeakingSessionState>(
      _resetFor(
        latest.copyWith(
          ratings: const <int, SpeakingSelfRating>{},
          savedQuestionIds: const <int>{},
          clearError: true,
        ),
        0,
      ),
    );
  }

  /// Re-checks the microphone permission (e.g. after the user grants it in the
  /// system settings) and returns the new value.
  Future<bool> recheckMicPermission() async {
    final SpeakingRecorder? recorder = _recorder;
    if (recorder == null) {
      return false;
    }
    bool granted = false;
    try {
      granted = await recorder.hasPermission();
    } on Object catch (error, stackTrace) {
      appLogger.warning('Microphone permission check failed.', error, stackTrace);
    }
    final SpeakingSessionState? current = state.valueOrNull;
    if (current != null) {
      state = AsyncData<SpeakingSessionState>(
        current.copyWith(micGranted: granted),
      );
    }
    return granted;
  }

  // --- internals ----------------------------------------------------------

  void _beginPrep(SpeakingSessionState current) {
    final int seconds = current.topic.effectivePrepSeconds;
    state = AsyncData<SpeakingSessionState>(
      current.copyWith(
        phase: SpeakingPhase.prep,
        remainingSeconds: seconds,
        totalSeconds: seconds,
        spokenSeconds: 0,
        clearRecordingPath: true,
        timedOut: false,
        clearError: true,
      ),
    );
    _startTicker();
  }

  Future<void> _beginSpeaking(SpeakingSessionState current) async {
    final SpeakingQuestion? question = current.current;
    if (question == null) {
      return;
    }
    _ticker?.cancel();
    _ticker = null;

    bool granted = current.micGranted ?? false;
    String? path;
    if (granted) {
      try {
        path = await speakingRecordingPath(
          topicId: current.topic.id,
          questionId: question.id,
          now: ref.read(clockProvider).now(),
        );
        await _recorder?.start(path);
      } on Object catch (error, stackTrace) {
        appLogger.warning('Recording start failed.', error, stackTrace);
        path = null;
        granted = false;
      }
    }

    final int seconds = current.topic.speakSeconds;
    state = AsyncData<SpeakingSessionState>(
      current.copyWith(
        phase: SpeakingPhase.speaking,
        remainingSeconds: seconds,
        totalSeconds: seconds,
        spokenSeconds: 0,
        recordingPath: path,
        clearRecordingPath: path == null,
        micGranted: granted,
        timedOut: false,
        clearError: true,
      ),
    );
    _startTicker();
  }

  Future<void> _finishSpeaking(
    SpeakingSessionState current, {
    bool timedOut = false,
  }) async {
    _ticker?.cancel();
    _ticker = null;

    final int spoken = current.totalSeconds - current.remainingSeconds;
    String? path = current.recordingPath;
    final SpeakingRecorder? recorder = _recorder;
    if (path != null && recorder != null) {
      try {
        path = await recorder.stop() ?? path;
      } on Object catch (error, stackTrace) {
        appLogger.warning('Recording stop failed.', error, stackTrace);
      }
    }

    state = AsyncData<SpeakingSessionState>(
      current.copyWith(
        phase: SpeakingPhase.review,
        remainingSeconds: 0,
        spokenSeconds: spoken < 0 ? 0 : spoken,
        recordingPath: path,
        timedOut: timedOut,
        clearError: true,
      ),
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      if (!_alive) {
        return;
      }
      final SpeakingSessionState? current = state.valueOrNull;
      if (current == null) {
        return;
      }
      if (current.phase != SpeakingPhase.prep &&
          current.phase != SpeakingPhase.speaking) {
        return;
      }
      final int remaining = current.remainingSeconds - 1;
      if (remaining > 0) {
        state = AsyncData<SpeakingSessionState>(
          current.copyWith(remainingSeconds: remaining),
        );
        return;
      }
      state = AsyncData<SpeakingSessionState>(
        current.copyWith(remainingSeconds: 0),
      );
      if (current.phase == SpeakingPhase.prep) {
        unawaited(_beginSpeaking(state.valueOrNull ?? current));
      } else {
        unawaited(
          _finishSpeaking(state.valueOrNull ?? current, timedOut: true),
        );
      }
    });
  }

  /// Stops the recorder without touching the state (used when the question is
  /// abandoned, e.g. by jumping to another question).
  Future<void> _stopRecorderQuietly() async {
    try {
      await _recorder?.stop();
    } on Object catch (error, stackTrace) {
      appLogger.warning('Recording stop failed.', error, stackTrace);
    }
  }

  /// Stops (if needed) and releases a recorder that is being thrown away.
  Future<void> _releaseRecorder(SpeakingRecorder recorder) async {
    try {
      await recorder.stop();
    } on Object catch (_) {
      // The recorder is being disposed anyway; a failed stop is not fatal.
    }
    try {
      await recorder.dispose();
    } on Object catch (error, stackTrace) {
      appLogger.warning('Recorder dispose failed.', error, stackTrace);
    }
  }

  /// Returns [source] reset for [index], keeping the topic, scores and saves.
  SpeakingSessionState _resetFor(
    SpeakingSessionState source,
    int index, {
    bool finished = false,
  }) {
    return SpeakingSessionState(
      topic: source.topic,
      questions: source.questions,
      currentIndex: index,
      phase: finished ? SpeakingPhase.finished : SpeakingPhase.ready,
      micGranted: source.micGranted,
      ratings: source.ratings,
      savedQuestionIds: source.savedQuestionIds,
    );
  }
}

/// Provider for one speaking session, keyed by topic id.
///
/// `autoDispose` so that leaving the session disposes the controller — and, with
/// it, the recorder (releasing the microphone) and the countdown timer.
final AutoDisposeAsyncNotifierProviderFamily<SpeakingSessionController,
        SpeakingSessionState, int> speakingSessionControllerProvider =
    AsyncNotifierProvider.autoDispose.family<SpeakingSessionController,
        SpeakingSessionState, int>(SpeakingSessionController.new);
