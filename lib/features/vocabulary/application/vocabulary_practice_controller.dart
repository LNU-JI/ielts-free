/// Vocabulary practice session (PRD §4.4 / BRIEF §15–16).
///
/// Runs a paper of the seven question kinds, grades each answer through the
/// unified write path ([SubmitAnswerUseCase]) — which updates the memory level,
/// the mistake queue, the skill score and today's statistics — and checkpoints
/// the run after **every** question so a mid-session kill resumes where it left
/// off (PRD Q-8 / FR-080).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/enums/ref_type.dart';
import 'package:ielts_free/core/models/json_utils.dart';
import 'package:ielts_free/core/models/learning_session.dart';
import 'package:ielts_free/core/models/vocabulary.dart';
import 'package:ielts_free/core/models/vocabulary_review.dart';
import 'package:ielts_free/core/providers/answer_providers.dart';
import 'package:ielts_free/core/providers/refresh_provider.dart';
import 'package:ielts_free/core/providers/repository_providers.dart';
import 'package:ielts_free/core/providers/service_providers.dart';
import 'package:ielts_free/core/services/grading_service.dart';
import 'package:ielts_free/core/services/session_autosave_service.dart';
import 'package:ielts_free/core/storage/repositories/progress_repository.dart';
import 'package:ielts_free/core/storage/repositories/vocabulary_repository.dart';
import 'package:ielts_free/core/utils/logger.dart';
import 'package:ielts_free/features/vocabulary/application/vocab_question_builder.dart';

/// One graded answer within a run.
@immutable
class VocabAnswerRecord {
  const VocabAnswerRecord({
    required this.index,
    required this.userAnswer,
    required this.isCorrect,
    required this.correctAnswer,
  });

  /// 0-based position of the question in the paper.
  final int index;

  /// What the user answered.
  final String userAnswer;

  /// Whether it was correct.
  final bool isCorrect;

  /// The canonical correct answer.
  final String correctAnswer;
}

/// Immutable vocabulary-practice state.
@immutable
class VocabPracticeState {
  const VocabPracticeState({
    this.items = const <VocabPracticeItem>[],
    this.answers = const <VocabAnswerRecord>[],
    this.currentIndex = 0,
    this.drafts = const <int, String>{},
    this.elapsedSeconds = 0,
    this.submitting = false,
    this.finished = false,
    this.restored = false,
    this.sessionId = '',
    this.error,
  });

  /// The questions in this paper.
  final List<VocabPracticeItem> items;

  /// Answers recorded so far.
  final List<VocabAnswerRecord> answers;

  /// The question currently shown.
  final int currentIndex;

  /// In-progress answer text per question index (for crash recovery).
  final Map<int, String> drafts;

  /// Seconds elapsed since the run started.
  final int elapsedSeconds;

  /// Whether a grade write is in flight.
  final bool submitting;

  /// Whether the run has been completed.
  final bool finished;

  /// Whether the run was resumed from a checkpoint.
  final bool restored;

  /// The autosave session id.
  final String sessionId;

  /// A user-facing error, or `null`.
  final String? error;

  /// Number of questions.
  int get total => items.length;

  /// The question currently shown, or `null` when the paper is empty.
  VocabPracticeItem? get current =>
      currentIndex >= 0 && currentIndex < items.length ? items[currentIndex] : null;

  /// Number of answered questions.
  int get answeredCount => answers.length;

  /// Number of correct answers.
  int get correctCount => answers.where((VocabAnswerRecord a) => a.isCorrect).length;

  /// Fraction answered in `[0, 1]`.
  double get progress => total == 0 ? 0 : answeredCount / total;

  /// Whether every question has been answered.
  bool get isComplete => total > 0 && answeredCount >= total;

  /// The answer record for the current question, or `null`.
  VocabAnswerRecord? get currentRecord {
    for (final VocabAnswerRecord record in answers) {
      if (record.index == currentIndex) {
        return record;
      }
    }
    return null;
  }

  /// Returns a copy with the given fields replaced.
  VocabPracticeState copyWith({
    List<VocabPracticeItem>? items,
    List<VocabAnswerRecord>? answers,
    int? currentIndex,
    Map<int, String>? drafts,
    int? elapsedSeconds,
    bool? submitting,
    bool? finished,
    bool? restored,
    String? sessionId,
    String? error,
    bool clearError = false,
  }) {
    return VocabPracticeState(
      items: items ?? this.items,
      answers: answers ?? this.answers,
      currentIndex: currentIndex ?? this.currentIndex,
      drafts: drafts ?? this.drafts,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      submitting: submitting ?? this.submitting,
      finished: finished ?? this.finished,
      restored: restored ?? this.restored,
      sessionId: sessionId ?? this.sessionId,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for a vocabulary practice run.
class VocabularyPracticeController extends AsyncNotifier<VocabPracticeState> {
  SessionAutosaveService? _autosave;
  Timer? _ticker;
  bool _alive = true;

  @override
  Future<VocabPracticeState> build() async {
    _alive = true;
    ref.onDispose(() {
      _alive = false;
      _ticker?.cancel();
      _ticker = null;
      _autosave?.dispose();
    });

    const String userId = AppConstants.localUserId;
    final ProgressRepository progress =
        await ref.read(progressRepositoryProvider.future);

    final LearningSession? active = await progress.activeSession(userId);
    final bool resumable = active != null &&
        active.sessionType == RefType.vocabulary &&
        active.checkpoint['paper'] is List;

    final VocabPracticeState initial =
        resumable ? await _restore(userId, active) : await _newPaper(userId);

    _autosave = SessionAutosaveService(
      progressRepository: progress,
      userId: userId,
      sessionType: RefType.vocabulary,
      clock: ref.read(clockProvider),
      sessionId: resumable ? active.id : null,
      startedAt: resumable ? (active.startedAt ?? ref.read(clockProvider).now()) : null,
    );
    await _autosave!.start(initialCheckpoint: _checkpoint(initial));
    _startTicker();

    return initial.copyWith(sessionId: _autosave!.sessionId, restored: resumable);
  }

  /// Grades the current question with [value] and records the result.
  Future<void> answer(String value) async {
    final VocabPracticeState? current = state.valueOrNull;
    if (current == null || current.submitting) {
      return;
    }
    final VocabPracticeItem? item = current.current;
    if (item == null || current.currentRecord != null) {
      return;
    }
    state = AsyncData<VocabPracticeState>(
      current.copyWith(submitting: true, clearError: true),
    );
    try {
      final result = await (await ref.read(submitAnswerUseCaseProvider.future))
          .submitVocabulary(
        userId: AppConstants.localUserId,
        vocabularyId: item.vocabulary.id ?? 0,
        kind: item.kind,
        expected: item.expected,
        actual: value,
        difficulty: item.vocabulary.difficulty,
        sessionId: current.sessionId.isEmpty ? null : current.sessionId,
      );
      final List<VocabAnswerRecord> answers = <VocabAnswerRecord>[
        ...current.answers,
        VocabAnswerRecord(
          index: current.currentIndex,
          userAnswer: value,
          isCorrect: result.isCorrect,
          correctAnswer: item.expected,
        ),
      ];
      final Map<int, String> drafts = Map<int, String>.of(current.drafts)
        ..remove(current.currentIndex);
      final VocabPracticeState updated = current.copyWith(
        answers: answers,
        drafts: drafts,
        submitting: false,
        clearError: true,
      );
      state = AsyncData<VocabPracticeState>(updated);
      await _autosave?.saveNow(_checkpoint(updated), itemsCompleted: answers.length);
    } on Object catch (error, stackTrace) {
      appLogger.warning('Vocabulary answer submit failed.', error, stackTrace);
      state = AsyncData<VocabPracticeState>(
        current.copyWith(submitting: false, error: failureFromException(error).message),
      );
    }
  }

  /// Advances to the next question, or finishes the run.
  Future<void> next() async {
    final VocabPracticeState? current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final int nextIndex = current.currentIndex + 1;
    if (nextIndex >= current.total) {
      await finish();
      return;
    }
    state = AsyncData<VocabPracticeState>(current.copyWith(currentIndex: nextIndex));
  }

  /// Stores a draft answer and schedules a debounced checkpoint.
  void saveDraft(String draft) {
    final VocabPracticeState? current = state.valueOrNull;
    if (current == null || _autosave == null) {
      return;
    }
    final Map<int, String> drafts = Map<int, String>.of(current.drafts)
      ..[current.currentIndex] = draft;
    final VocabPracticeState updated = current.copyWith(drafts: drafts);
    state = AsyncData<VocabPracticeState>(updated);
    _autosave!.checkpoint(_checkpoint(updated));
  }

  /// Completes the run, persisting the final checkpoint.
  Future<void> finish() async {
    final VocabPracticeState? current = state.valueOrNull;
    if (current == null || current.finished) {
      return;
    }
    final VocabPracticeState done = current.copyWith(finished: true);
    state = AsyncData<VocabPracticeState>(done);
    await _autosave?.complete(
      itemsCompleted: done.answeredCount,
      checkpoint: _checkpoint(done),
    );
    notifyDataChanged(ref);
  }

  /// Starts a fresh run.
  Future<void> restart() async {
    const String userId = AppConstants.localUserId;
    final ProgressRepository progress =
        await ref.read(progressRepositoryProvider.future);
    final VocabPracticeState fresh = await _newPaper(userId);
    _autosave?.dispose();
    _autosave = SessionAutosaveService(
      progressRepository: progress,
      userId: userId,
      sessionType: RefType.vocabulary,
      clock: ref.read(clockProvider),
    );
    await _autosave!.start(initialCheckpoint: _checkpoint(fresh));
    state = AsyncData<VocabPracticeState>(
      fresh.copyWith(sessionId: _autosave!.sessionId),
    );
  }

  // --- paper construction -------------------------------------------------

  Future<VocabPracticeState> _newPaper(String userId) async {
    final List<Vocabulary> pool = await _loadPool(userId);
    final List<VocabPracticeItem> items =
        const VocabQuestionBuilder().build(pool);
    return VocabPracticeState(items: items);
  }

  Future<VocabPracticeState> _restore(String userId, LearningSession session) async {
    final List<Map<String, Object?>> paper = decodeMapList(session.checkpoint['paper']);
    final List<Map<String, Object?>> answers =
        decodeMapList(session.checkpoint['answers']);
    final Map<String, Object?> draftsRaw =
        decodeMap(session.checkpoint['drafts']) ?? const <String, Object?>{};

    final VocabularyRepository repository =
        await ref.read(vocabularyRepositoryProvider.future);
    final List<Vocabulary> pool = await _loadPool(userId);
    const VocabQuestionBuilder builder = VocabQuestionBuilder();

    final List<VocabPracticeItem> items = <VocabPracticeItem>[];
    for (final Map<String, Object?> entry in paper) {
      final int? id = asInt(entry['vid']);
      final VocabQuestionKind kind = _kindFromWire(asString(entry['kind']));
      if (id == null) {
        continue;
      }
      Vocabulary? word = await repository.byId(id);
      if (word == null) {
        for (final Vocabulary candidate in pool) {
          if (candidate.id == id) {
            word = candidate;
            break;
          }
        }
      }
      if (word != null) {
        items.add(builder.buildOne(word, kind, pool));
      }
    }

    final List<VocabAnswerRecord> records = <VocabAnswerRecord>[];
    for (final Map<String, Object?> entry in answers) {
      records.add(
        VocabAnswerRecord(
          index: intOrDefault(entry['index'], 0),
          userAnswer: asString(entry['userAnswer']) ?? '',
          isCorrect: asBool(entry['isCorrect']),
          correctAnswer: asString(entry['correctAnswer']) ?? '',
        ),
      );
    }

    final Map<int, String> drafts = <int, String>{};
    draftsRaw.forEach((String key, Object? value) {
      final int? index = int.tryParse(key);
      if (index != null && value is String) {
        drafts[index] = value;
      }
    });

    int currentIndex = intOrDefault(session.checkpoint['currentIndex'], 0);
    if (currentIndex < 0 || currentIndex >= items.length) {
      currentIndex = items.isEmpty ? 0 : items.length - 1;
    }

    return VocabPracticeState(
      items: items,
      answers: records,
      drafts: drafts,
      currentIndex: currentIndex,
    );
  }

  Future<List<Vocabulary>> _loadPool(String userId) async {
    final ProgressRepository progress =
        await ref.read(progressRepositoryProvider.future);
    final VocabularyRepository repository =
        await ref.read(vocabularyRepositoryProvider.future);

    final List<Vocabulary> words = <Vocabulary>[];
    final Set<int> seen = <int>{};

    final due = await progress.dueReviews(userId, page: 1, pageSize: 20);
    for (final VocabularyReview review in due.items) {
      final int id = review.vocabularyId;
      if (seen.add(id)) {
        final Vocabulary? word = await repository.byId(id);
        if (word != null) {
          words.add(word);
        }
      }
    }

    final fill = await repository.list(page: 1, pageSize: 60);
    for (final Vocabulary word in fill.items) {
      final int? id = word.id;
      if (id != null && seen.add(id)) {
        words.add(word);
      }
    }
    return words;
  }

  // --- helpers ------------------------------------------------------------

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      if (!_alive) {
        return;
      }
      final VocabPracticeState? current = state.valueOrNull;
      if (current == null || current.finished) {
        return;
      }
      state = AsyncData<VocabPracticeState>(
        current.copyWith(elapsedSeconds: current.elapsedSeconds + 1),
      );
    });
  }

  Map<String, Object?> _checkpoint(VocabPracticeState s) => <String, Object?>{
        'paper': s.items
            .map(
              (VocabPracticeItem i) => <String, Object?>{
                'vid': i.vocabulary.id,
                'kind': i.kind.wire,
              },
            )
            .toList(),
        'answers': s.answers
            .map(
              (VocabAnswerRecord a) => <String, Object?>{
                'index': a.index,
                'userAnswer': a.userAnswer,
                'isCorrect': a.isCorrect,
                'correctAnswer': a.correctAnswer,
              },
            )
            .toList(),
        'currentIndex': s.currentIndex,
        'drafts': s.drafts.map(
          (int key, String value) => MapEntry<String, Object?>(key.toString(), value),
        ),
      };

  VocabQuestionKind _kindFromWire(String? wire) {
    for (final VocabQuestionKind kind in VocabQuestionKind.values) {
      if (kind.wire == wire) {
        return kind;
      }
    }
    return VocabQuestionKind.wordToMeaning;
  }
}

/// Provider for the vocabulary practice controller.
final AsyncNotifierProvider<VocabularyPracticeController, VocabPracticeState>
    vocabularyPracticeControllerProvider =
    AsyncNotifierProvider<VocabularyPracticeController, VocabPracticeState>(
  VocabularyPracticeController.new,
);
