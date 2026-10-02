/// Reading list state (PRD §4.5 / BRIEF §17).
///
/// Loads a paged slice of the reading bank with optional topic / difficulty
/// filters. Every query is `LIMIT` / `OFFSET`-bounded (FR-023).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/reading_passage.dart';
import 'package:ielts_free/core/providers/repository_providers.dart';
import 'package:ielts_free/core/storage/paging.dart';
import 'package:ielts_free/core/storage/repositories/reading_repository.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Immutable reading-list state.
@immutable
class ReadingListState {
  const ReadingListState({
    this.items = const <ReadingPassage>[],
    this.total = 0,
    this.page = 1,
    this.pageSize = AppConstants.defaultPageSize,
    this.hasMore = false,
    this.loadingMore = false,
    this.topic,
    this.difficulty,
    this.topics = const <String>[],
    this.error,
  });

  /// Passages loaded so far.
  final List<ReadingPassage> items;

  /// Total passages matching the filter.
  final int total;

  /// Highest page loaded.
  final int page;

  /// Page size.
  final int pageSize;

  /// Whether more rows exist.
  final bool hasMore;

  /// Whether an extra page is loading.
  final bool loadingMore;

  /// Active topic filter, or `null`.
  final String? topic;

  /// Active difficulty filter, or `null`.
  final int? difficulty;

  /// Distinct topics for the filter chips.
  final List<String> topics;

  /// A user-facing error, or `null`.
  final String? error;

  /// Returns a copy with the given fields replaced.
  ReadingListState copyWith({
    List<ReadingPassage>? items,
    int? total,
    int? page,
    int? pageSize,
    bool? hasMore,
    bool? loadingMore,
    String? topic,
    int? difficulty,
    List<String>? topics,
    String? error,
    bool clearTopic = false,
    bool clearDifficulty = false,
    bool clearError = false,
  }) {
    return ReadingListState(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      topic: clearTopic ? null : (topic ?? this.topic),
      difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
      topics: topics ?? this.topics,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for the reading list.
class ReadingListController extends AsyncNotifier<ReadingListState> {
  @override
  Future<ReadingListState> build() async {
    final ReadingRepository repository =
        await ref.read(readingRepositoryProvider.future);
    final List<String> topics = await repository.topics();
    final PagedList<ReadingPassage> first = await repository.list(
      page: 1,
      pageSize: AppConstants.defaultPageSize,
    );
    return ReadingListState(
      items: first.items,
      total: first.total,
      page: 1,
      hasMore: first.hasMore,
      topics: topics,
    );
  }

  /// Applies a topic filter (`null` clears it) and reloads from page 1.
  Future<void> setTopic(String? topic) =>
      _reload((ReadingListState s) => s.copyWith(topic: topic, clearTopic: topic == null));

  /// Applies a difficulty filter (`null` clears it) and reloads from page 1.
  Future<void> setDifficulty(int? difficulty) => _reload(
        (ReadingListState s) => s.copyWith(
          difficulty: difficulty,
          clearDifficulty: difficulty == null,
        ),
      );

  /// Loads the next page and appends it.
  Future<void> loadMore() async {
    final ReadingListState? current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) {
      return;
    }
    state = AsyncData<ReadingListState>(
      current.copyWith(loadingMore: true, clearError: true),
    );
    try {
      final ReadingRepository repository =
          await ref.read(readingRepositoryProvider.future);
      final PagedList<ReadingPassage> next = await repository.list(
        page: current.page + 1,
        pageSize: current.pageSize,
        topic: current.topic,
        difficulty: current.difficulty,
      );
      final List<ReadingPassage> merged = <ReadingPassage>[
        ...current.items,
        ...next.items.where(
          (ReadingPassage p) => !current.items.any((ReadingPassage e) => e.id == p.id),
        ),
      ];
      state = AsyncData<ReadingListState>(
        current.copyWith(
          items: merged,
          total: next.total,
          page: current.page + 1,
          hasMore: next.hasMore,
          loadingMore: false,
        ),
      );
    } on Object catch (error, stackTrace) {
      appLogger.warning('Reading page load failed.', error, stackTrace);
      state = AsyncData<ReadingListState>(
        current.copyWith(loadingMore: false, error: failureFromException(error).message),
      );
    }
  }

  /// Reloads from page 1 keeping the current filters.
  Future<void> refresh() => _reload((ReadingListState s) => s);

  // --- internals ----------------------------------------------------------

  Future<void> _reload(ReadingListState Function(ReadingListState) mutate) async {
    final ReadingListState current =
        state.valueOrNull ?? const ReadingListState();
    final ReadingListState next = mutate(current);
    state = AsyncData<ReadingListState>(
      next.copyWith(
        items: const <ReadingPassage>[],
        page: 1,
        loadingMore: false,
        clearError: true,
      ),
    );
    try {
      final ReadingRepository repository =
          await ref.read(readingRepositoryProvider.future);
      final PagedList<ReadingPassage> page = await repository.list(
        page: 1,
        pageSize: next.pageSize,
        topic: next.topic,
        difficulty: next.difficulty,
      );
      state = AsyncData<ReadingListState>(
        next.copyWith(
          items: page.items,
          total: page.total,
          page: 1,
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
    } on Object catch (error, stackTrace) {
      appLogger.warning('Reading list reload failed.', error, stackTrace);
      state = AsyncData<ReadingListState>(
        next.copyWith(items: const <ReadingPassage>[], error: failureFromException(error).message),
      );
    }
  }
}

/// Provider for the reading list.
final AsyncNotifierProvider<ReadingListController, ReadingListState>
    readingListControllerProvider =
    AsyncNotifierProvider<ReadingListController, ReadingListState>(
  ReadingListController.new,
);
