/// Vocabulary detail state (PRD §4.3 / BRIEF §14).
///
/// Loads one word, its topics and the user's review state, and exposes the four
/// actions of the detail page: 🔊发音 / ⭐收藏 / ✓掌握 / ✗不认识.
///
/// The 掌握 / 不认识 actions are **self-reports**, not graded questions, so they
/// update the memory level and the review schedule directly (PRD §4.3: 「操作即
/// 更新记忆等级与复习计划」). They deliberately do **not** create a `mistakes`
/// row or a `user_answers` row — the mistake queue is fed by graded practice and
/// reading answers (BRIEF §28), which keeps statistics meaningful.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/vocabulary.dart';
import 'package:ielts_free/core/models/vocabulary_review.dart';
import 'package:ielts_free/core/models/vocabulary_topic.dart';
import 'package:ielts_free/core/providers/refresh_provider.dart';
import 'package:ielts_free/core/providers/repository_providers.dart';
import 'package:ielts_free/core/providers/service_providers.dart';
import 'package:ielts_free/core/services/clock_service.dart';
import 'package:ielts_free/core/services/submit_answer_usecase.dart';
import 'package:ielts_free/core/storage/repositories/progress_repository.dart';
import 'package:ielts_free/core/storage/repositories/vocabulary_repository.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Immutable vocabulary-detail state.
@immutable
class VocabularyDetailState {
  const VocabularyDetailState({
    required this.vocabulary,
    this.review,
    this.topics = const <String>[],
    this.busy = false,
    this.error,
  });

  /// The word being viewed.
  final Vocabulary vocabulary;

  /// The user's review state, or `null` when the word is untouched.
  final VocabularyReview? review;

  /// Topics attached to the word.
  final List<String> topics;

  /// Whether a write is in flight.
  final bool busy;

  /// A user-facing error, or `null`.
  final String? error;

  /// Whether the word is favourited.
  bool get isFavorite => review?.isFavorite ?? false;

  /// The current memory level (`0` when untouched).
  int get memoryLevel => review?.memoryLevel ?? 0;

  /// Whether the word has reached the "mastered" level.
  bool get isMastered => review?.isMastered ?? false;

  /// Returns a copy with the given fields replaced.
  VocabularyDetailState copyWith({
    VocabularyReview? review,
    List<String>? topics,
    bool? busy,
    String? error,
    bool clearError = false,
  }) {
    return VocabularyDetailState(
      vocabulary: vocabulary,
      review: review ?? this.review,
      topics: topics ?? this.topics,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for the vocabulary detail page.
class VocabularyDetailController
    extends FamilyAsyncNotifier<VocabularyDetailState, int> {
  @override
  Future<VocabularyDetailState> build(int vocabularyId) async {
    final VocabularyRepository repository =
        await ref.read(vocabularyRepositoryProvider.future);
    final Vocabulary? vocabulary = await repository.byId(vocabularyId);
    if (vocabulary == null) {
      throw const NotFoundException('VOCAB_NOT_FOUND', '未找到该词汇。');
    }
    final List<String> topics = (await repository.topicsFor(vocabularyId))
        .map((VocabularyTopic t) => t.topic)
        .where((String t) => t.isNotEmpty)
        .toList(growable: false);
    final ProgressRepository progress =
        await ref.read(progressRepositoryProvider.future);
    final VocabularyReview? review =
        await progress.reviewFor(AppConstants.localUserId, vocabularyId);
    return VocabularyDetailState(
      vocabulary: vocabulary,
      review: review,
      topics: topics,
    );
  }

  /// Toggles the favourite flag.
  Future<void> toggleFavorite() async {
    final VocabularyDetailState? current = state.valueOrNull;
    if (current == null || current.busy) {
      return;
    }
    state = AsyncData<VocabularyDetailState>(current.copyWith(busy: true, clearError: true));
    try {
      final ProgressRepository progress =
          await ref.read(progressRepositoryProvider.future);
      await progress.setFavorite(
        AppConstants.localUserId,
        arg,
        !current.isFavorite,
      );
      final VocabularyReview? review =
          await progress.reviewFor(AppConstants.localUserId, arg);
      state = AsyncData<VocabularyDetailState>(
        current.copyWith(review: review, busy: false, clearError: true),
      );
      notifyDataChanged(ref);
    } on Object catch (error, stackTrace) {
      appLogger.warning('Vocabulary favourite toggle failed.', error, stackTrace);
      state = AsyncData<VocabularyDetailState>(
        current.copyWith(busy: false, error: failureFromException(error).message),
      );
    }
  }

  /// Self-report "I know this word" → memory level +1.
  Future<void> markKnown() => _applyMemory(correct: true);

  /// Self-report "I don't know this word" → memory level −1.
  Future<void> markUnknown() => _applyMemory(correct: false);

  // --- internals ----------------------------------------------------------

  Future<void> _applyMemory({required bool correct}) async {
    final VocabularyDetailState? current = state.valueOrNull;
    if (current == null || current.busy) {
      return;
    }
    state = AsyncData<VocabularyDetailState>(current.copyWith(busy: true, clearError: true));
    try {
      final ProgressRepository progress =
          await ref.read(progressRepositoryProvider.future);
      final Clock clock = ref.read(clockProvider);
      final VocabularyReview review = current.review ??
          VocabularyReview(userId: AppConstants.localUserId, vocabularyId: arg);
      final VocabularyReview updated = ref
          .read(memoryServiceProvider)
          .applyResult(review, correct: correct);
      final bool mastered =
          updated.memoryLevel >= SubmitAnswerUseCase.masteredMemoryLevel;
      await progress.saveReview(
        updated.copyWith(isMastered: mastered, updatedAt: clock.now()),
      );
      final VocabularyReview? reloaded =
          await progress.reviewFor(AppConstants.localUserId, arg);
      state = AsyncData<VocabularyDetailState>(
        current.copyWith(review: reloaded, busy: false, clearError: true),
      );
      notifyDataChanged(ref);
    } on Object catch (error, stackTrace) {
      appLogger.warning('Vocabulary memory update failed.', error, stackTrace);
      state = AsyncData<VocabularyDetailState>(
        current.copyWith(busy: false, error: failureFromException(error).message),
      );
    }
  }
}

/// Provider for the vocabulary detail controller, keyed by vocabulary id.
final AsyncNotifierProviderFamily<VocabularyDetailController,
        VocabularyDetailState, int> vocabularyDetailControllerProvider =
    AsyncNotifierProvider.family<VocabularyDetailController,
        VocabularyDetailState, int>(VocabularyDetailController.new);
