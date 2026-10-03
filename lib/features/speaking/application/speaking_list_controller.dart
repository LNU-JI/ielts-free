/// Speaking topic list (PRD §4.6 / BRIEF §20).
///
/// Loads a paged slice of the speaking bank grouped by Part 1 / 2 / 3. For every
/// topic it also resolves how many questions it holds and whether the learner
/// has practised it at least once, so the list can show 题量 and 是否练过.
///
/// Every query is `LIMIT` / `OFFSET`-bounded (FR-023).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/enums/speaking_part.dart';
import 'package:ielts_free/core/models/speaking_attempt.dart';
import 'package:ielts_free/core/models/speaking_question.dart';
import 'package:ielts_free/core/models/speaking_topic.dart';
import 'package:ielts_free/core/providers/speaking_provider.dart';
import 'package:ielts_free/core/storage/paging.dart';
import 'package:ielts_free/core/storage/repositories/speaking_repository.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// One row of the speaking list: the topic plus its derived metadata.
@immutable
class SpeakingTopicEntry {
  const SpeakingTopicEntry({
    required this.topic,
    required this.questionCount,
    required this.practised,
  });

  /// The topic itself.
  final SpeakingTopic topic;

  /// How many questions the topic holds.
  final int questionCount;

  /// Whether at least one question of the topic has been attempted.
  final bool practised;
}

/// Immutable speaking-list state.
@immutable
class SpeakingListState {
  const SpeakingListState({
    this.entries = const <SpeakingTopicEntry>[],
    this.total = 0,
    this.page = 1,
    this.pageSize = AppConstants.defaultPageSize,
    this.hasMore = false,
    this.loadingMore = false,
    this.error,
  });

  /// Topics loaded so far.
  final List<SpeakingTopicEntry> entries;

  /// Total topics matching the query.
  final int total;

  /// Highest page loaded.
  final int page;

  /// Page size.
  final int pageSize;

  /// Whether more rows exist.
  final bool hasMore;

  /// Whether an extra page is loading.
  final bool loadingMore;

  /// A user-facing error, or `null`.
  final String? error;

  /// The entries of one [part], in load order.
  List<SpeakingTopicEntry> entriesFor(SpeakingPart part) => entries
      .where((SpeakingTopicEntry e) => e.topic.part == part)
      .toList(growable: false);

  /// Returns a copy with the given fields replaced.
  SpeakingListState copyWith({
    List<SpeakingTopicEntry>? entries,
    int? total,
    int? page,
    int? pageSize,
    bool? hasMore,
    bool? loadingMore,
    String? error,
    bool clearError = false,
  }) {
    return SpeakingListState(
      entries: entries ?? this.entries,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for the speaking topic list.
class SpeakingListController extends AsyncNotifier<SpeakingListState> {
  @override
  Future<SpeakingListState> build() async {
    final SpeakingRepository repository =
        await ref.read(speakingRepositoryProvider.future);
    final PagedList<SpeakingTopic> first = await repository.listTopics(
      page: 1,
      pageSize: AppConstants.defaultPageSize,
    );
    final List<SpeakingTopicEntry> entries = await _describe(repository, first.items);
    return SpeakingListState(
      entries: entries,
      total: first.total,
      page: 1,
      hasMore: first.hasMore,
    );
  }

  /// Loads the next page and appends it.
  Future<void> loadMore() async {
    final SpeakingListState? current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) {
      return;
    }
    state = AsyncData<SpeakingListState>(
      current.copyWith(loadingMore: true, clearError: true),
    );
    try {
      final SpeakingRepository repository =
          await ref.read(speakingRepositoryProvider.future);
      final PagedList<SpeakingTopic> next = await repository.listTopics(
        page: current.page + 1,
        pageSize: current.pageSize,
      );
      final List<SpeakingTopicEntry> described =
          await _describe(repository, next.items);
      final List<SpeakingTopicEntry> merged = <SpeakingTopicEntry>[
        ...current.entries,
        ...described.where(
          (SpeakingTopicEntry e) =>
              !current.entries.any((SpeakingTopicEntry o) => o.topic.id == e.topic.id),
        ),
      ];
      state = AsyncData<SpeakingListState>(
        current.copyWith(
          entries: merged,
          total: next.total,
          page: current.page + 1,
          hasMore: next.hasMore,
          loadingMore: false,
        ),
      );
    } on Object catch (error, stackTrace) {
      appLogger.warning('Speaking page load failed.', error, stackTrace);
      state = AsyncData<SpeakingListState>(
        current.copyWith(
          loadingMore: false,
          error: failureFromException(error).message,
        ),
      );
    }
  }

  /// Reloads from page 1.
  Future<void> refresh() async {
    final SpeakingListState current =
        state.valueOrNull ?? const SpeakingListState();
    state = AsyncData<SpeakingListState>(
      current.copyWith(
        entries: const <SpeakingTopicEntry>[],
        page: 1,
        loadingMore: false,
        clearError: true,
      ),
    );
    try {
      final SpeakingRepository repository =
          await ref.read(speakingRepositoryProvider.future);
      final PagedList<SpeakingTopic> first = await repository.listTopics(
        page: 1,
        pageSize: current.pageSize,
      );
      state = AsyncData<SpeakingListState>(
        current.copyWith(
          entries: await _describe(repository, first.items),
          total: first.total,
          page: 1,
          hasMore: first.hasMore,
          loadingMore: false,
        ),
      );
    } on Object catch (error, stackTrace) {
      appLogger.warning('Speaking list reload failed.', error, stackTrace);
      state = AsyncData<SpeakingListState>(
        current.copyWith(
          entries: const <SpeakingTopicEntry>[],
          error: failureFromException(error).message,
        ),
      );
    }
  }

  // --- internals ----------------------------------------------------------

  /// Attaches question count + practised flag to each topic.
  Future<List<SpeakingTopicEntry>> _describe(
    SpeakingRepository repository,
    List<SpeakingTopic> topics,
  ) async {
    final List<SpeakingTopicEntry> entries = await Future.wait(
      topics.map((SpeakingTopic topic) => _describeOne(repository, topic)),
    );
    return entries;
  }

  Future<SpeakingTopicEntry> _describeOne(
    SpeakingRepository repository,
    SpeakingTopic topic,
  ) async {
    final SpeakingTopic? detail = await repository.topicDetail(topic.id);
    final List<SpeakingQuestion> questions =
        detail?.questions ?? const <SpeakingQuestion>[];
    bool practised = false;
    for (final SpeakingQuestion question in questions) {
      final List<SpeakingAttempt> attempts = await repository.attemptsForQuestion(
        AppConstants.localUserId,
        question.id,
        limit: 1,
      );
      if (attempts.isNotEmpty) {
        practised = true;
        break;
      }
    }
    return SpeakingTopicEntry(
      topic: topic,
      questionCount: questions.length,
      practised: practised,
    );
  }
}

/// Provider for the speaking topic list.
final AsyncNotifierProvider<SpeakingListController, SpeakingListState>
    speakingListControllerProvider =
    AsyncNotifierProvider<SpeakingListController, SpeakingListState>(
  SpeakingListController.new,
);
