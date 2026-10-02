/// Mistakes list state (PRD §4.6 / BRIEF §28).
///
/// Shows the active mistake queue, filterable by type (全部 / 词汇 / 阅读) and
/// paged with `LIMIT` / `OFFSET` (FR-023). Mastered mistakes fade from the
/// active queue automatically (`mastery >= 0.80`).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/enums/ref_type.dart';
import 'package:ielts_free/core/models/mistake.dart';
import 'package:ielts_free/core/providers/repository_providers.dart';
import 'package:ielts_free/core/storage/paging.dart';
import 'package:ielts_free/core/storage/repositories/mistake_repository.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Immutable mistakes-list state.
@immutable
class MistakesState {
  const MistakesState({
    this.items = const <Mistake>[],
    this.total = 0,
    this.page = 1,
    this.pageSize = AppConstants.defaultPageSize,
    this.hasMore = false,
    this.loadingMore = false,
    this.filter,
    this.activeCount = 0,
    this.error,
  });

  /// The mistakes loaded so far.
  final List<Mistake> items;

  /// Total mistakes matching the filter.
  final int total;

  /// Highest page loaded.
  final int page;

  /// Page size.
  final int pageSize;

  /// Whether more rows exist.
  final bool hasMore;

  /// Whether an extra page is loading.
  final bool loadingMore;

  /// Active type filter, or `null` for all.
  final RefType? filter;

  /// Number of active (unmastered) mistakes.
  final int activeCount;

  /// A user-facing error, or `null`.
  final String? error;

  /// Returns a copy with the given fields replaced.
  MistakesState copyWith({
    List<Mistake>? items,
    int? total,
    int? page,
    int? pageSize,
    bool? hasMore,
    bool? loadingMore,
    RefType? filter,
    int? activeCount,
    String? error,
    bool clearFilter = false,
    bool clearError = false,
  }) {
    return MistakesState(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      filter: clearFilter ? null : (filter ?? this.filter),
      activeCount: activeCount ?? this.activeCount,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for the mistakes list.
class MistakesController extends AsyncNotifier<MistakesState> {
  @override
  Future<MistakesState> build() async {
    final MistakeRepository repository =
        await ref.read(mistakeRepositoryProvider.future);
    final PagedList<Mistake> first = await repository.list(
      AppConstants.localUserId,
      page: 1,
      pageSize: AppConstants.defaultPageSize,
    );
    final int activeCount = await repository.countActive(AppConstants.localUserId);
    return MistakesState(
      items: first.items,
      total: first.total,
      page: 1,
      hasMore: first.hasMore,
      activeCount: activeCount,
    );
  }

  /// Applies a type filter (`null` clears it) and reloads from page 1.
  Future<void> setFilter(RefType? filter) => _reload(
        (MistakesState s) => s.copyWith(filter: filter, clearFilter: filter == null),
      );

  /// Loads the next page and appends it.
  Future<void> loadMore() async {
    final MistakesState? current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) {
      return;
    }
    state = AsyncData<MistakesState>(
      current.copyWith(loadingMore: true, clearError: true),
    );
    try {
      final MistakeRepository repository =
          await ref.read(mistakeRepositoryProvider.future);
      final PagedList<Mistake> next = await repository.list(
        AppConstants.localUserId,
        page: current.page + 1,
        pageSize: current.pageSize,
        refType: current.filter,
      );
      final List<Mistake> merged = <Mistake>[
        ...current.items,
        ...next.items.where(
          (Mistake m) => !current.items.any((Mistake e) => e.id == m.id),
        ),
      ];
      state = AsyncData<MistakesState>(
        current.copyWith(
          items: merged,
          total: next.total,
          page: current.page + 1,
          hasMore: next.hasMore,
          loadingMore: false,
        ),
      );
    } on Object catch (error, stackTrace) {
      appLogger.warning('Mistakes page load failed.', error, stackTrace);
      state = AsyncData<MistakesState>(
        current.copyWith(loadingMore: false, error: failureFromException(error).message),
      );
    }
  }

  /// Reloads from page 1 keeping the current filter.
  Future<void> refresh() => _reload((MistakesState s) => s);

  // --- internals ----------------------------------------------------------

  Future<void> _reload(MistakesState Function(MistakesState) mutate) async {
    final MistakesState current = state.valueOrNull ?? const MistakesState();
    final MistakesState next = mutate(current);
    state = AsyncData<MistakesState>(
      next.copyWith(items: const <Mistake>[], page: 1, loadingMore: false, clearError: true),
    );
    try {
      final MistakeRepository repository =
          await ref.read(mistakeRepositoryProvider.future);
      final PagedList<Mistake> page = await repository.list(
        AppConstants.localUserId,
        page: 1,
        pageSize: next.pageSize,
        refType: next.filter,
      );
      final int activeCount = await repository.countActive(AppConstants.localUserId);
      state = AsyncData<MistakesState>(
        next.copyWith(
          items: page.items,
          total: page.total,
          page: 1,
          hasMore: page.hasMore,
          activeCount: activeCount,
          loadingMore: false,
        ),
      );
    } on Object catch (error, stackTrace) {
      appLogger.warning('Mistakes reload failed.', error, stackTrace);
      state = AsyncData<MistakesState>(
        next.copyWith(items: const <Mistake>[], error: failureFromException(error).message),
      );
    }
  }
}

/// Provider for the mistakes list.
final AsyncNotifierProvider<MistakesController, MistakesState>
    mistakesControllerProvider =
    AsyncNotifierProvider<MistakesController, MistakesState>(
  MistakesController.new,
);
