/// Reading session (PRD §4.5 / BRIEF §18–19).
///
/// Runs one passage: shows the text beside the questions, times the attempt,
/// **auto-submits and grades when the clock expires** (PRD Q-9), checkpoints
/// after every answered question and writes every answer through the unified
/// write path so the loop (mistakes, skill scores, statistics) stays consistent.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/enums/ref_type.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/models/learning_session.dart';
import 'package:ielts_free/core/models/reading_passage.dart';
import 'package:ielts_free/core/models/reading_question.dart';
import 'package:ielts_free/core/providers/answer_providers.dart';
import 'package:ielts_free/core/providers/refresh_provider.dart';
import 'package:ielts_free/core/providers/repository_providers.dart';
import 'package:ielts_free/core/providers/service_providers.dart';
import 'package:ielts_free/core/services/session_autosave_service.dart';
import 'package:ielts_free/core/storage/repositories/progress_repository.dart';
import 'package:ielts_free/core/storage/repositories/reading_repository.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Immutable reading-session state.
@immutable
class ReadingSessionState {
  const ReadingSessionState({
    required this.passage,
    this.questions = const <ReadingQuestion>[],
    this.answers = const <int, String>{},
    this.results = const <int, bool>{},
    this.currentIndex = 0,
    this.remainingSeconds = 0,
    this.totalSeconds = 0,
    this.elapsedSeconds = 0,
    this.submitted = false,
    this.autoSubmitted = false,
    this.submitting = false,
    this.restored = false,
    this.sessionId = '',
    this.error,
  });

  /// The passage being attempted.
  final ReadingPassage passage;

  /// The passage's questions.
  final List<ReadingQuestion> questions;

  /// Answers keyed by question id.
  final Map<int, String> answers;

  /// Grading results keyed by question id (populated after submit).
  final Map<int, bool> results;

  /// The question currently shown.
  final int currentIndex;

  /// Seconds left before auto-submit.
  final int remainingSeconds;

  /// Total seconds allowed for the attempt.
  final int totalSeconds;

  /// Seconds elapsed since the attempt began.
  final int elapsedSeconds;

  /// Whether the attempt has been graded.
  final bool submitted;

  /// Whether the attempt was auto-submitted on timeout (PRD Q-9).
  final bool autoSubmitted;

  /// Whether grading is in flight.
  final bool submitting;

  /// Whether the attempt was resumed from a checkpoint.
  final bool restored;

  /// The autosave session id.
  final String sessionId;

  /// A user-facing error, or `null`.
  final String? error;

  /// Number of questions.
  int get total => questions.length;

  /// The question currently shown, or `null`.
  ReadingQuestion? get current =>
      currentIndex >= 0 && currentIndex < questions.length
          ? questions[currentIndex]
          : null;

  /// Number of answered questions.
  int get answeredCount =>
      questions.where((ReadingQuestion q) => (answers[q.id] ?? '').trim().isNotEmpty).length;

  /// Number of correct answers (after submit).
  int get correctCount => results.values.where((bool v) => v).length;

  /// Fraction answered in `[0, 1]`.
  double get progress => total == 0 ? 0 : answeredCount / total;

  /// Whether every question has an answer.
  bool get allAnswered => total > 0 && answeredCount >= total;

  /// The answer for [questionId], or `''`.
  String answerFor(int questionId) => answers[questionId] ?? '';

  /// The result for [questionId], or `null` before submit.
  bool? resultFor(int questionId) => results[questionId];

  /// Returns a copy with the given fields replaced.
  ReadingSessionState copyWith({
    List<ReadingQuestion>? questions,
    Map<int, String>? answers,
    Map<int, bool>? results,
    int? currentIndex,
    int? remainingSeconds,
    int? totalSeconds,
    int? elapsedSeconds,
    bool? submitted,
    bool? autoSubmitted,
    bool? submitting,
    bool? restored,
    String? sessionId,
    String? error,
    bool clearError = false,
  }) {
    return ReadingSessionState(
      passage: passage,
      questions: questions ?? this.questions,
      answers: answers ?? this.answers,
      results: results ?? this.results,
      currentIndex: currentIndex ?? this.currentIndex,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      submitted: submitted ?? this.submitted,
      autoSubmitted: autoSubmitted ?? this.autoSubmitted,
      submitting: submitting ?? this.submitting,
      restored: restored ?? this.restored,
      sessionId: sessionId ?? this.sessionId,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for one reading attempt.
class ReadingSessionController
    extends FamilyAsyncNotifier<ReadingSessionState, int> {
  /// Default attempt length when the passage carries no suggested time.
  static const int defaultSeconds = 20 * 60;

  SessionAutosaveService? _autosave;
  Timer? _ticker;
  bool _alive = true;

  @override
  Future<ReadingSessionState> build(int passageId) async {
    _alive = true;
    ref.onDispose(() {
      _alive = false;
      _ticker?.cancel();
      _ticker = null;
      _autosave?.dispose();
    });

    const String userId = AppConstants.localUserId;
    final ReadingRepository repository =
        await ref.read(readingRepositoryProvider.future);
    final ReadingPassage? passage = await repository.passageById(passageId);
    if (passage == null) {
      throw const NotFoundException('READING_NOT_FOUND', '未找到该阅读文章。');
    }
    final List<ReadingQuestion> questions =
        await repository.questionsWithOptions(passageId);

    final int totalSeconds = passage.readingTimeSec ?? defaultSeconds;

    final ProgressRepository progress =
        await ref.read(progressRepositoryProvider.future);
    final LearningSession? active = await progress.activeSession(userId);
    final bool resumable = active != null &&
        active.sessionType == RefType.reading &&
        intOrDefault(active.checkpoint['passageId'], -1) == passageId;

    final ReadingSessionState initial = resumable
        ? _restore(passage, questions, active, totalSeconds)
        : ReadingSessionState(
            passage: passage,
            questions: questions,
            remainingSeconds: totalSeconds,
            totalSeconds: totalSeconds,
          );

    _autosave = SessionAutosaveService(
      progressRepository: progress,
      userId: userId,
      sessionType: RefType.reading,
      clock: ref.read(clockProvider),
      sessionId: resumable ? active.id : null,
      startedAt: resumable ? (active.startedAt ?? ref.read(clockProvider).now()) : null,
    );
    await _autosave!.start(initialCheckpoint: _checkpoint(initial));
    _startTicker();

    return initial.copyWith(sessionId: _autosave!.sessionId, restored: resumable);
  }

  /// Records the current question's answer and schedules a debounced checkpoint.
  void answer(String value) {
    final ReadingSessionState? current = state.valueOrNull;
    if (current == null || current.submitted) {
      return;
    }
    final ReadingQuestion? question = current.current;
    if (question == null) {
      return;
    }
    final Map<int, String> answers = Map<int, String>.of(current.answers)
      ..[question.id] = value;
    final ReadingSessionState updated = current.copyWith(answers: answers);
    state = AsyncData<ReadingSessionState>(updated);
    _autosave?.checkpoint(_checkpoint(updated));
  }

  /// Moves to [index] and takes an immediate per-question checkpoint (PRD Q-8).
  Future<void> goTo(int index) async {
    final ReadingSessionState? current = state.valueOrNull;
    if (current == null || index < 0 || index >= current.questions.length) {
      return;
    }
    final ReadingSessionState updated = current.copyWith(currentIndex: index);
    state = AsyncData<ReadingSessionState>(updated);
    await _autosave?.saveNow(
      _checkpoint(updated),
      itemsCompleted: updated.answeredCount,
    );
  }

  /// Moves to the next / previous question.
  Future<void> next() => goTo((state.valueOrNull?.currentIndex ?? 0) + 1);

  /// Moves to the previous question.
  Future<void> previous() => goTo((state.valueOrNull?.currentIndex ?? 0) - 1);

  /// Grades every question and completes the attempt.
  ///
  /// [auto] marks the submit as a timeout auto-submit (PRD Q-9).
  Future<void> submit({bool auto = false}) async {
    final ReadingSessionState? current = state.valueOrNull;
    if (current == null || current.submitted || current.submitting) {
      return;
    }
    state = AsyncData<ReadingSessionState>(
      current.copyWith(submitting: true, clearError: true),
    );
    try {
      final useCase = await ref.read(submitAnswerUseCaseProvider.future);
      final int total = current.questions.length;
      final int perQuestionMs =
          total == 0 ? 0 : ((current.elapsedSeconds * 1000) / total).round();

      final Map<int, bool> results = <int, bool>{};
      for (final ReadingQuestion question in current.questions) {
        final result = await useCase.submitReading(
          userId: AppConstants.localUserId,
          question: question,
          userAnswer: current.answerFor(question.id),
          timeSpentMs: perQuestionMs,
          sessionId: current.sessionId.isEmpty ? null : current.sessionId,
        );
        results[question.id] = result.isCorrect;
      }

      final ReadingSessionState updated = current.copyWith(
        results: results,
        submitted: true,
        autoSubmitted: auto,
        submitting: false,
        clearError: true,
      );
      state = AsyncData<ReadingSessionState>(updated);
      _ticker?.cancel();
      _ticker = null;
      await _autosave?.complete(
        itemsCompleted: total,
        checkpoint: _checkpoint(updated),
      );
      notifyDataChanged(ref);
    } on Object catch (error, stackTrace) {
      appLogger.warning('Reading submit failed.', error, stackTrace);
      state = AsyncData<ReadingSessionState>(
        current.copyWith(submitting: false, error: failureFromException(error).message),
      );
    }
  }

  /// Starts a fresh attempt at the same passage.
  Future<void> restart() async {
    final ReadingSessionState? current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final ProgressRepository progress =
        await ref.read(progressRepositoryProvider.future);
    final ReadingSessionState fresh = ReadingSessionState(
      passage: current.passage,
      questions: current.questions,
      remainingSeconds: current.totalSeconds,
      totalSeconds: current.totalSeconds,
    );
    _autosave?.dispose();
    _autosave = SessionAutosaveService(
      progressRepository: progress,
      userId: AppConstants.localUserId,
      sessionType: RefType.reading,
      clock: ref.read(clockProvider),
    );
    await _autosave!.start(initialCheckpoint: _checkpoint(fresh));
    state = AsyncData<ReadingSessionState>(
      fresh.copyWith(sessionId: _autosave!.sessionId),
    );
    _startTicker();
  }

  // --- internals ----------------------------------------------------------

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      if (!_alive) {
        return;
      }
      final ReadingSessionState? current = state.valueOrNull;
      if (current == null || current.submitted) {
        return;
      }
      final int remaining = current.remainingSeconds - 1;
      if (remaining <= 0) {
        state = AsyncData<ReadingSessionState>(
          current.copyWith(remainingSeconds: 0, elapsedSeconds: current.elapsedSeconds + 1),
        );
        // Time is up → auto-submit and grade (PRD Q-9).
        unawaited(submit(auto: true));
        return;
      }
      state = AsyncData<ReadingSessionState>(
        current.copyWith(
          remainingSeconds: remaining,
          elapsedSeconds: current.elapsedSeconds + 1,
        ),
      );
    });
  }

  ReadingSessionState _restore(
    ReadingPassage passage,
    List<ReadingQuestion> questions,
    LearningSession session,
    int totalSeconds,
  ) {
    final Map<String, Object?> rawAnswers =
        decodeMap(session.checkpoint['answers']) ?? const <String, Object?>{};
    final Map<int, String> answers = <int, String>{};
    rawAnswers.forEach((String key, Object? value) {
      final int? id = int.tryParse(key);
      if (id != null && value is String) {
        answers[id] = value;
      }
    });

    int currentIndex = intOrDefault(session.checkpoint['currentIndex'], 0);
    if (currentIndex < 0 || currentIndex >= questions.length) {
      currentIndex = 0;
    }
    int remaining = intOrDefault(session.checkpoint['remaining'], totalSeconds);
    if (remaining <= 0) {
      remaining = totalSeconds;
    }

    return ReadingSessionState(
      passage: passage,
      questions: questions,
      answers: answers,
      currentIndex: currentIndex,
      remainingSeconds: remaining,
      totalSeconds: totalSeconds,
      elapsedSeconds: totalSeconds - remaining,
    );
  }

  Map<String, Object?> _checkpoint(ReadingSessionState s) => <String, Object?>{
        'passageId': s.passage.id,
        'answers': s.answers.map(
          (int key, String value) => MapEntry<String, Object?>(key.toString(), value),
        ),
        'currentIndex': s.currentIndex,
        'remaining': s.remainingSeconds,
      };
}

/// Provider for a reading attempt, keyed by passage id.
final AsyncNotifierProviderFamily<ReadingSessionController,
        ReadingSessionState, int> readingSessionControllerProvider =
    AsyncNotifierProvider.family<ReadingSessionController,
        ReadingSessionState, int>(ReadingSessionController.new);
