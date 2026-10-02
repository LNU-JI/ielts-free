/// Vocabulary list state (PRD §4.1 / BRIEF §13).
///
/// Loads a **paged** slice of the vocabulary bank with optional topic / difficulty
/// filters and a free-text search. Every query is bounded by `LIMIT` / `OFFSET`
/// (FR-023, ARCHITECTURE §9.4): the list never loads the whole bank at once.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/vocabulary.dart';
import 'package:ielts_free/core/providers/repository_providers.dart';
import 'package:ielts_free/core/storage/paging.dart';
import 'package:ielts_free/core/storage/repositories/vocabulary_repository.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Immutable vocabulary-list state.
@immutable
class VocabularyListState {
  const VocabularyListState({
    this.items = const <Vocabulary>[],
    this.total = 0,
    this.page = 1,
    this.pageSize = AppConstants.defaultPageSize,
    this.hasMore = false,
    this.loadingMore = false,
    this.topic,
    this.difficulty,
    this.query = '',
    this.topics = const <String>[],
    this.error,
  });

  /// The words currently loaded (accumulated across pages).
  final List<Vocabulary> items;

  /// Total rows matching the active filter (as reported by the repository).
  final int total;

  /// The highest page loaded so far.
  final int page;

  /// Page size.
  final int pageSize;

  /// Whether more rows exist beyond [items].
  final bool hasMore;

  /// Whether an additional page is loading.
  final bool loadingMore;

  /// Active topic filter, or `null` for all topics.
  final String? topic;

  /// Active difficulty filter, or `null` for all levels.
  final int? difficulty;

  /// Free-text search query.
  final String query;

  /// Distinct topics for the filter chips.
  final List<String> topics;

  /// A user-facing error, or `null`.
  final String? error;

  /// Whether any filter is active.
  bool get hasFilter =>
      (topic != null) || (difficulty != null) || query.trim().isNotEmpty;

  /// Returns a copy with the given fields replaced.
  VocabularyListState copyWith({
    List<Vocabulary>? items,
    int? total,
    int? page,
    int? pageSize,
    bool? hasMore,
    bool? loadingMore,
    String? topic,
    int? difficulty,
    String? query,
    List<String>? topics,
    String? error,
    bool clearTopic = false,
    bool clearDifficulty = false,
    bool clearError = false,
  }) {
    return VocabularyListState(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      topic: clearTopic ? null : (topic ?? this.topic),
      difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
      query: query ?? this.query,
      topics: topics ?? this.topics,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for the vocabulary list.
class VocabularyListController extends AsyncNotifier<VocabularyListState> {
  @override
  Future<VocabularyListState> build() async {
    final VocabularyRepository repository =
        await ref.read(vocabularyRepositoryProvider.future);
    final List<String> topics = await repository.topics();
    final PagedList<Vocabulary> first = await repository.list(
      page: 1,
      pageSize: AppConstants.defaultPageSize,
    );
    return VocabularyListState(
      items: first.items,
      total: first.total,
      page: 1,
      hasMore: first.hasMore,
      topics: topics,
    );
  }

  /// Applies a topic filter (`null` clears it) and reloads from page 1.
  Future<void> setTopic(String? topic) =>
      _reload((VocabularyListState s) => s.copyWith(topic: topic, clearTopic: topic == null));

  /// Applies a difficulty filter (`null` clears it) and reloads from page 1.
  Future<void> setDifficulty(int? difficulty) => _reload(
        (VocabularyListState s) => s.copyWith(
          difficulty: difficulty,
          clearDifficulty: difficulty == null,
        ),
      );

  /// Applies a search query and reloads from page 1.
  Future<void> setQuery(String query) =>
      _reload((VocabularyListState s) => s.copyWith(query: query));

  /// Loads the next page and appends it.
  Future<void> loadMore() async {
    final VocabularyListState? current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) {
      return;
    }
    state = AsyncData<VocabularyListState>(
      current.copyWith(loadingMore: true, clearError: true),
    );
    try {
      final VocabularyRepository repository =
          await ref.read(vocabularyRepositoryProvider.future);
      final PagedList<Vocabulary> next = await repository.list(
        page: current.page + 1,
        pageSize: current.pageSize,
        topic: current.topic,
        difficulty: current.difficulty,
        query: current.query.trim().isEmpty ? null : current.query.trim(),
      );
      final List<Vocabulary> merged = <Vocabulary>[
        ...current.items,
        ...next.items.where(
          (Vocabulary v) => !current.items.any((Vocabulary e) => e.id == v.id),
        ),
      ];
      state = AsyncData<VocabularyListState>(
        current.copyWith(
          items: merged,
          total: next.total,
          page: current.page + 1,
          hasMore: next.hasMore,
          loadingMore: false,
        ),
      );
    } on Object catch (error, stackTrace) {
      appLogger.warning('Vocabulary page load failed.', error, stackTrace);
      state = AsyncData<VocabularyListState>(
        current.copyWith(loadingMore: false, error: _message(error)),
      );
    }
  }

  /// Reloads from page 1 keeping the current filters.
  Future<void> refresh() => _reload((VocabularyListState s) => s);

  // --- internals ----------------------------------------------------------

  Future<void> _reload(VocabularyListState Function(VocabularyListState) mutate) async {
    final VocabularyListState current =
        state.valueOrNull ?? const VocabularyListState();
    final VocabularyListState next = mutate(current);
    state = AsyncData<VocabularyListState>(
      next.copyWith(items: const <Vocabulary>[], page: 1, loadingMore: false, clearError: true),
    );
    try {
      final VocabularyRepository repository =
          await ref.read(vocabularyRepositoryProvider.future);
      final PagedList<Vocabulary> page = await repository.list(
        page: 1,
        pageSize: next.pageSize,
        topic: next.topic,
        difficulty: next.difficulty,
        query: next.query.trim().isEmpty ? null : next.query.trim(),
      );
      state = AsyncData<VocabularyListState>(
        next.copyWith(
          items: page.items,
          total: page.total,
          page: 1,
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
    } on Object catch (error, stackTrace) {
      appLogger.warning('Vocabulary list reload failed.', error, stackTrace);
      state = AsyncData<VocabularyListState>(
        next.copyWith(items: const <Vocabulary>[], error: _message(error)),
      );
    }
  }

  String _message(Object error) => failureFromException(error).message;
}

/// Provider for the vocabulary list.
final AsyncNotifierProvider<VocabularyListController, VocabularyListState>
    vocabularyListControllerProvider =
    AsyncNotifierProvider<VocabularyListController, VocabularyListState>(
  VocabularyListController.new,
);
