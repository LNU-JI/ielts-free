/// Writing controllers (PRD §4.6 / BRIEF §20).
///
/// Three independent state machines power the writing module:
///
/// - [WritingListController] — the task list, grouped by Task 1 / Task 2, with
///   the latest attempt per task so the list can mark what has been written;
/// - [WritingSessionController] — one timed attempt: show the prompt (and, for
///   Task 1, the chart), optionally preview the outline, count down, count
///   words live, then persist the attempt and unlock the model essay;
/// - [PhraseBankController] — the phrase library grouped by category, with
///   one-tap collection into `phrase_book`.
///
/// There is deliberately **no AI feedback**: the offline stand-ins are the
/// model essay + annotations and the phrase bank (product red line).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/phrase_entry.dart';
import 'package:ielts_free/core/models/writing_attempt.dart';
import 'package:ielts_free/core/models/writing_phrase.dart';
import 'package:ielts_free/core/models/writing_task.dart';
import 'package:ielts_free/core/providers/refresh_provider.dart';
import 'package:ielts_free/core/providers/service_providers.dart';
import 'package:ielts_free/core/providers/writing_provider.dart';
import 'package:ielts_free/core/storage/paging.dart';
import 'package:ielts_free/core/storage/repositories/writing_repository.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Upper bound for the one-shot content queries (task / phrase library).
///
/// The shipped writing bank is small and fully offline, so a single bounded
/// page is simpler than paginating a list the learner scrolls through.
const int _kWritingContentLimit = 500;

/// Counts words in [text], treating each CJK / kana / Hangul character as one
/// word and each run of Latin letters / digits (allowing internal apostrophes
/// and hyphens) as one word.
///
/// This mirrors how IELTS counts words closely enough for the live counter: it
/// ignores punctuation and whitespace and stays sensible for mixed
/// Chinese–English drafts.
int countWritingWords(String text) {
  if (text.trim().isEmpty) {
    return 0;
  }
  return _writingWordPattern.allMatches(text).length;
}

/// One Latin word (with optional internal apostrophe / hyphen) or one CJK,
/// kana or Hangul character.
final RegExp _writingWordPattern = RegExp(
  r"[A-Za-z0-9]+(?:['\u2019-][A-Za-z0-9]+)*"
  r"|[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uac00-\ud7af]",
);

// --- Task list --------------------------------------------------------------

/// Immutable writing-list state.
@immutable
class WritingListState {
  const WritingListState({
    this.task1 = const <WritingTask>[],
    this.task2 = const <WritingTask>[],
    this.latest = const <int, WritingAttempt>{},
    this.totalWords = 0,
    this.error,
  });

  /// Task 1 (data description) tasks.
  final List<WritingTask> task1;

  /// Task 2 (discursive essay) tasks.
  final List<WritingTask> task2;

  /// The most recent attempt per task id.
  final Map<int, WritingAttempt> latest;

  /// Total words written across all attempts.
  final int totalWords;

  /// A user-facing error, or `null`.
  final String? error;

  /// Whether there is nothing to show.
  bool get isEmpty => task1.isEmpty && task2.isEmpty;

  /// Whether [taskId] already has at least one recorded attempt.
  bool hasWritten(int taskId) => latest.containsKey(taskId);

  /// The most recent attempt for [taskId], or `null`.
  WritingAttempt? attemptFor(int taskId) => latest[taskId];
}

/// Controller for the writing task list.
class WritingListController extends AsyncNotifier<WritingListState> {
  @override
  Future<WritingListState> build() async {
    // Rebuild whenever another screen writes user data (e.g. a saved attempt).
    ref.watch(dataRevisionProvider);
    return _load();
  }

  /// Reloads the list.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<WritingListState> _load() async {
    final WritingRepository repository =
        await ref.read(writingRepositoryProvider.future);
    final PagedList<WritingTask> first = await repository.listTasks(
      page: 1,
      pageSize: _kWritingContentLimit,
      task: 1,
    );
    final PagedList<WritingTask> second = await repository.listTasks(
      page: 1,
      pageSize: _kWritingContentLimit,
      task: 2,
    );

    final Map<int, WritingAttempt> latest = <int, WritingAttempt>{};
    for (final WritingTask task in <WritingTask>[...first.items, ...second.items]) {
      final WritingAttempt? attempt =
          await repository.latestAttempt(AppConstants.localUserId, task.id);
      if (attempt != null) {
        latest[task.id] = attempt;
      }
    }

    final int totalWords = await repository.totalWordCount(
      AppConstants.localUserId,
    );

    return WritingListState(
      task1: first.items,
      task2: second.items,
      latest: latest,
      totalWords: totalWords,
    );
  }
}

/// Provider for the writing task list.
final AsyncNotifierProvider<WritingListController, WritingListState>
    writingListControllerProvider =
    AsyncNotifierProvider<WritingListController, WritingListState>(
  WritingListController.new,
);

// --- One timed attempt ------------------------------------------------------

/// Where an attempt is in its lifecycle.
enum WritingPhase {
  /// Prompt shown; the clock has not started.
  ready,

  /// The clock is running (or has run out) and the learner is writing.
  writing,

  /// Saved; the model essay is unlocked.
  finished,
}

/// Immutable writing-session state.
@immutable
class WritingSessionState {
  const WritingSessionState({
    required this.task,
    this.content = '',
    this.wordCount = 0,
    this.phase = WritingPhase.ready,
    this.showOutline = false,
    this.showSample = false,
    this.remainingSeconds = 0,
    this.totalSeconds = 0,
    this.elapsedSeconds = 0,
    this.timeUp = false,
    this.restored = false,
    this.saved = false,
    this.saving = false,
    this.selfRating,
    this.error,
  });

  /// The task being attempted (with its model essays attached).
  final WritingTask task;

  /// The essay body.
  final String content;

  /// Live word count of [content].
  final int wordCount;

  /// Lifecycle phase.
  final WritingPhase phase;

  /// Whether the outline preview is expanded.
  final bool showOutline;

  /// Whether the model essay panel is expanded.
  final bool showSample;

  /// Seconds left on the clock.
  final int remainingSeconds;

  /// Total seconds allowed for the attempt.
  final int totalSeconds;

  /// Seconds elapsed since the attempt began.
  final int elapsedSeconds;

  /// Whether the clock has run out (writing may continue).
  final bool timeUp;

  /// Whether a previous attempt was loaded as a draft.
  final bool restored;

  /// Whether the attempt has been saved.
  final bool saved;

  /// Whether a save is in flight.
  final bool saving;

  /// Optional self-assessment label.
  final String? selfRating;

  /// A user-facing error, or `null`.
  final String? error;

  /// Whether the draft is below the task's minimum length.
  bool get underLength => wordCount < task.minWords;

  /// Whether the essay body is empty.
  bool get isEmptyDraft => content.trim().isEmpty;

  /// Fraction of the clock consumed in `[0, 1]`.
  double get progress {
    if (totalSeconds <= 0) {
      return 0;
    }
    final double value = 1 - (remainingSeconds / totalSeconds);
    return value.clamp(0, 1);
  }

  /// Returns a copy with the given fields replaced.
  WritingSessionState copyWith({
    String? content,
    int? wordCount,
    WritingPhase? phase,
    bool? showOutline,
    bool? showSample,
    int? remainingSeconds,
    int? totalSeconds,
    int? elapsedSeconds,
    bool? timeUp,
    bool? restored,
    bool? saved,
    bool? saving,
    String? selfRating,
    String? error,
    bool clearSelfRating = false,
    bool clearError = false,
  }) {
    return WritingSessionState(
      task: task,
      content: content ?? this.content,
      wordCount: wordCount ?? this.wordCount,
      phase: phase ?? this.phase,
      showOutline: showOutline ?? this.showOutline,
      showSample: showSample ?? this.showSample,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      timeUp: timeUp ?? this.timeUp,
      restored: restored ?? this.restored,
      saved: saved ?? this.saved,
      saving: saving ?? this.saving,
      selfRating: clearSelfRating ? null : (selfRating ?? this.selfRating),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for one writing attempt, keyed by task id.
class WritingSessionController
    extends FamilyAsyncNotifier<WritingSessionState, int> {
  Timer? _ticker;

  @override
  Future<WritingSessionState> build(int taskId) async {
    ref.onDispose(() {
      _ticker?.cancel();
      _ticker = null;
    });

    final WritingRepository repository =
        await ref.read(writingRepositoryProvider.future);
    final WritingTask? task = await repository.taskDetail(taskId);
    if (task == null) {
      throw const NotFoundException('WRITING_NOT_FOUND', '未找到该写作题目。');
    }

    final WritingAttempt? latest =
        await repository.latestAttempt(AppConstants.localUserId, taskId);
    final int totalSeconds = task.timeMinutes * 60;

    return WritingSessionState(
      task: task,
      content: latest?.content ?? '',
      wordCount: countWritingWords(latest?.content ?? ''),
      totalSeconds: totalSeconds,
      remainingSeconds: totalSeconds,
      restored: latest != null && (latest.content.trim().isNotEmpty),
      selfRating: latest?.selfRating,
    );
  }

  /// Starts the countdown.
  void start() {
    final WritingSessionState? current = state.valueOrNull;
    if (current == null || current.phase != WritingPhase.ready) {
      return;
    }
    state = AsyncData<WritingSessionState>(
      current.copyWith(phase: WritingPhase.writing, clearError: true),
    );
    _startTicker();
  }

  /// Records the essay body and recomputes the word count.
  void updateContent(String text) {
    final WritingSessionState? current = state.valueOrNull;
    if (current == null || current.phase == WritingPhase.finished) {
      return;
    }
    state = AsyncData<WritingSessionState>(
      current.copyWith(content: text, wordCount: countWritingWords(text)),
    );
  }

  /// Sets (or clears) the optional self-assessment.
  void setSelfRating(String? rating) {
    final WritingSessionState? current = state.valueOrNull;
    if (current == null) {
      return;
    }
    state = AsyncData<WritingSessionState>(
      current.copyWith(selfRating: rating, clearSelfRating: rating == null),
    );
  }

  /// Toggles the outline preview.
  void toggleOutline() {
    final WritingSessionState? current = state.valueOrNull;
    if (current == null) {
      return;
    }
    state = AsyncData<WritingSessionState>(
      current.copyWith(showOutline: !current.showOutline),
    );
  }

  /// Toggles the model-essay panel.
  void toggleSample() {
    final WritingSessionState? current = state.valueOrNull;
    if (current == null) {
      return;
    }
    state = AsyncData<WritingSessionState>(
      current.copyWith(showSample: !current.showSample),
    );
  }

  /// Persists the attempt and finishes the run.
  Future<void> save() async {
    final WritingSessionState? current = state.valueOrNull;
    if (current == null || current.saved || current.saving || current.isEmptyDraft) {
      return;
    }
    state = AsyncData<WritingSessionState>(
      current.copyWith(saving: true, clearError: true),
    );
    try {
      final WritingRepository repository =
          await ref.read(writingRepositoryProvider.future);
      await repository.saveAttempt(
        WritingAttempt(
          userId: AppConstants.localUserId,
          taskId: current.task.id,
          taskNumber: current.task.task,
          content: current.content,
          wordCount: current.wordCount,
          durationSec: current.elapsedSeconds,
          selfRating: current.selfRating,
          createdAt: ref.read(clockProvider).now().toUtc(),
        ),
      );
      _ticker?.cancel();
      _ticker = null;
      state = AsyncData<WritingSessionState>(
        current.copyWith(
          phase: WritingPhase.finished,
          saved: true,
          saving: false,
          showSample: true,
          clearError: true,
        ),
      );
      notifyDataChanged(ref);
    } on Object catch (error, stackTrace) {
      appLogger.warning('Writing attempt save failed.', error, stackTrace);
      state = AsyncData<WritingSessionState>(
        current.copyWith(
          saving: false,
          error: failureFromException(error).message,
        ),
      );
    }
  }

  /// Starts a fresh attempt at the same task.
  void restart() {
    final WritingSessionState? current = state.valueOrNull;
    if (current == null) {
      return;
    }
    _ticker?.cancel();
    _ticker = null;
    state = AsyncData<WritingSessionState>(
      WritingSessionState(
        task: current.task,
        totalSeconds: current.totalSeconds,
        remainingSeconds: current.totalSeconds,
      ),
    );
  }

  // --- internals ----------------------------------------------------------

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      final WritingSessionState? current = state.valueOrNull;
      if (current == null || current.phase != WritingPhase.writing) {
        return;
      }
      if (current.timeUp) {
        _ticker?.cancel();
        _ticker = null;
        return;
      }
      final int remaining = current.remainingSeconds - 1;
      if (remaining <= 0) {
        _ticker?.cancel();
        _ticker = null;
        state = AsyncData<WritingSessionState>(
          current.copyWith(
            remainingSeconds: 0,
            elapsedSeconds: current.elapsedSeconds + 1,
            timeUp: true,
          ),
        );
        return;
      }
      state = AsyncData<WritingSessionState>(
        current.copyWith(
          remainingSeconds: remaining,
          elapsedSeconds: current.elapsedSeconds + 1,
        ),
      );
    });
  }
}

/// Provider for a writing attempt, keyed by task id.
final AsyncNotifierProviderFamily<WritingSessionController,
        WritingSessionState, int> writingSessionControllerProvider =
    AsyncNotifierProvider.family<WritingSessionController,
        WritingSessionState, int>(WritingSessionController.new);

// --- Phrase bank ------------------------------------------------------------

/// A category of phrases in the bank.
@immutable
class PhraseGroup {
  const PhraseGroup({required this.category, required this.phrases});

  /// The category label (e.g. `开头` / `让步`).
  final String category;

  /// The phrases in this category.
  final List<WritingPhrase> phrases;
}

/// Immutable phrase-bank state.
@immutable
class PhraseBankState {
  const PhraseBankState({
    this.groups = const <PhraseGroup>[],
    this.bookmarkedIds = const <int>{},
    this.error,
  });

  /// Phrases grouped by category.
  final List<PhraseGroup> groups;

  /// Ids of phrases already collected into the phrase book.
  final Set<int> bookmarkedIds;

  /// A user-facing error, or `null`.
  final String? error;

  /// Whether the bank is empty.
  bool get isEmpty => groups.isEmpty;

  /// Whether [phraseId] has been collected.
  bool isBookmarked(int phraseId) => bookmarkedIds.contains(phraseId);

  /// Returns a copy with the given fields replaced.
  PhraseBankState copyWith({
    List<PhraseGroup>? groups,
    Set<int>? bookmarkedIds,
    String? error,
    bool clearError = false,
  }) {
    return PhraseBankState(
      groups: groups ?? this.groups,
      bookmarkedIds: bookmarkedIds ?? this.bookmarkedIds,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for the phrase bank.
class PhraseBankController extends AsyncNotifier<PhraseBankState> {
  @override
  Future<PhraseBankState> build() async {
    final WritingRepository repository =
        await ref.read(writingRepositoryProvider.future);
    final PagedList<WritingPhrase> page = await repository.phrases(
      page: 1,
      pageSize: _kWritingContentLimit,
    );
    final PagedList<PhraseEntry> book = await repository.bookmarkedPhrases(
      AppConstants.localUserId,
      page: 1,
      pageSize: _kWritingContentLimit,
    );

    final Map<String, List<WritingPhrase>> byCategory =
        <String, List<WritingPhrase>>{};
    for (final WritingPhrase phrase in page.items) {
      byCategory
          .putIfAbsent(phrase.category, () => <WritingPhrase>[])
          .add(phrase);
    }

    final Set<int> bookmarkedIds = <int>{
      for (final PhraseEntry entry in book.items)
        if (entry.phraseId != null) entry.phraseId!,
    };

    return PhraseBankState(
      groups: <PhraseGroup>[
        for (final MapEntry<String, List<WritingPhrase>> entry
            in byCategory.entries)
          PhraseGroup(category: entry.key, phrases: entry.value),
      ],
      bookmarkedIds: bookmarkedIds,
    );
  }

  /// Collects [phrase] into the phrase book (idempotent).
  Future<void> bookmark(WritingPhrase phrase) async {
    final PhraseBankState? current = state.valueOrNull;
    if (current == null || current.bookmarkedIds.contains(phrase.id)) {
      return;
    }
    try {
      final WritingRepository repository =
          await ref.read(writingRepositoryProvider.future);
      await repository.bookmarkPhrase(
        PhraseEntry(
          userId: AppConstants.localUserId,
          phraseId: phrase.id,
          phrase: phrase.phrase,
          meaningCn: phrase.meaningCn,
          category: phrase.category,
          source: 'writing',
          createdAt: ref.read(clockProvider).now().toUtc(),
        ),
      );
      state = AsyncData<PhraseBankState>(
        current.copyWith(
          bookmarkedIds: <int>{...current.bookmarkedIds, phrase.id},
          clearError: true,
        ),
      );
      notifyDataChanged(ref);
    } on Object catch (error, stackTrace) {
      appLogger.warning('Phrase bookmark failed.', error, stackTrace);
      state = AsyncData<PhraseBankState>(
        current.copyWith(error: failureFromException(error).message),
      );
    }
  }
}

/// Provider for the phrase bank.
final AsyncNotifierProvider<PhraseBankController, PhraseBankState>
    phraseBankControllerProvider =
    AsyncNotifierProvider<PhraseBankController, PhraseBankState>(
  PhraseBankController.new,
);
