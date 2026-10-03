/// Listening section list (the 精听 picker).
///
/// Loads the sections from the read-only content database and, for each one,
/// whether the learner has already logged a listening mistake there — the
/// "practised" badge that tells a returning user where to continue.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/listening_error.dart';
import 'package:ielts_free/core/models/listening_section.dart';
import 'package:ielts_free/core/providers/listening_provider.dart';
import 'package:ielts_free/core/providers/refresh_provider.dart';
import 'package:ielts_free/core/storage/paging.dart';
import 'package:ielts_free/core/storage/repositories/listening_repository.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Immutable listening-list state.
@immutable
class ListeningListState {
  const ListeningListState({
    this.items = const <ListeningSection>[],
    this.practiced = const <int>{},
    this.total = 0,
    this.loading = true,
    this.error,
  });

  /// Sections to show.
  final List<ListeningSection> items;

  /// Section ids with at least one logged listening error.
  final Set<int> practiced;

  /// Total sections in the content database.
  final int total;

  /// Whether a (re)load is in flight.
  final bool loading;

  /// A user-facing error, or `null`.
  final String? error;

  /// Whether [sectionId] has been practised before.
  bool isPracticed(int sectionId) => practiced.contains(sectionId);

  /// Returns a copy with the given fields replaced.
  ListeningListState copyWith({
    List<ListeningSection>? items,
    Set<int>? practiced,
    int? total,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return ListeningListState(
      items: items ?? this.items,
      practiced: practiced ?? this.practiced,
      total: total ?? this.total,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for the listening section list.
class ListeningListController extends AsyncNotifier<ListeningListState> {
  @override
  Future<ListeningListState> build() async {
    // Recompute when a session writes an error / bookmark elsewhere.
    ref.watch(dataRevisionProvider);
    return _load();
  }

  /// Reloads the list and its practised badges.
  Future<void> refresh() async {
    final ListeningListState current =
        state.valueOrNull ?? const ListeningListState();
    state = AsyncData<ListeningListState>(
      current.copyWith(loading: true, clearError: true),
    );
    state = AsyncData<ListeningListState>(await _load());
  }

  Future<ListeningListState> _load() async {
    try {
      final ListeningRepository repository =
          await ref.read(listeningRepositoryProvider.future);
      final PagedList<ListeningSection> page =
          await repository.listSections(page: 1, pageSize: 100);

      final Set<int> practiced = <int>{};
      for (final ListeningSection section in page.items) {
        final List<ListeningError> errors = await repository.errorsForSection(
          AppConstants.localUserId,
          section.id,
        );
        if (errors.isNotEmpty) {
          practiced.add(section.id);
        }
      }

      return ListeningListState(
        items: page.items,
        practiced: practiced,
        total: page.total,
        loading: false,
      );
    } on Object catch (error, stackTrace) {
      appLogger.warning('Listening list load failed.', error, stackTrace);
      return ListeningListState(
        loading: false,
        error: failureFromException(error).message,
      );
    }
  }
}

/// Provider for the listening section list.
final AsyncNotifierProvider<ListeningListController, ListeningListState>
    listeningListControllerProvider =
    AsyncNotifierProvider<ListeningListController, ListeningListState>(
  ListeningListController.new,
);
