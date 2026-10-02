/// Mistake detail state (PRD §4.6 / BRIEF §28, ARCHITECTURE §5.7).
///
/// Loads one mistake plus the content it refers to (a word or a reading
/// question), and exposes the **redo** action: a correct redo raises the
/// mistake's `mastery` by `+0.30`; once `mastery >= 0.80` the mistake is mastered
/// and fades from the active queue. A wrong redo lowers it by `−0.20`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/core/errors/error_handler.dart';
import 'package:ielts_free/core/models/enums/ref_type.dart';
import 'package:ielts_free/core/models/mistake.dart';
import 'package:ielts_free/core/models/reading_question.dart';
import 'package:ielts_free/core/models/vocabulary.dart';
import 'package:ielts_free/core/providers/answer_providers.dart';
import 'package:ielts_free/core/providers/refresh_provider.dart';
import 'package:ielts_free/core/providers/repository_providers.dart';
import 'package:ielts_free/core/services/grading_service.dart';
import 'package:ielts_free/core/services/submit_answer_usecase.dart';
import 'package:ielts_free/core/storage/repositories/mistake_repository.dart';
import 'package:ielts_free/core/utils/logger.dart';

/// Immutable mistake-detail state.
@immutable
class MistakeDetailState {
  const MistakeDetailState({
    required this.mistake,
    this.vocabulary,
    this.readingQuestion,
    this.busy = false,
    this.lastRedoCorrect,
    this.error,
  });

  /// The mistake being viewed.
  final Mistake mistake;

  /// The word, when the mistake is a vocabulary mistake.
  final Vocabulary? vocabulary;

  /// The reading question, when the mistake is a reading mistake.
  final ReadingQuestion? readingQuestion;

  /// Whether a redo write is in flight.
  final bool busy;

  /// Whether the most recent redo was correct, or `null` before any redo.
  final bool? lastRedoCorrect;

  /// A user-facing error, or `null`.
  final String? error;

  /// The mistake's current mastery in `[0, 1]`.
  double get mastery => mistake.mastery;

  /// Whether the mistake has been mastered.
  bool get isMastered => mistake.isMastered;

  /// Whether the referenced content could be loaded for a redo.
  bool get canRedo => vocabulary != null || readingQuestion != null;

  /// Returns a copy with the given fields replaced.
  MistakeDetailState copyWith({
    Mistake? mistake,
    bool? busy,
    bool? lastRedoCorrect,
    String? error,
    bool clearRedo = false,
    bool clearError = false,
  }) {
    return MistakeDetailState(
      mistake: mistake ?? this.mistake,
      vocabulary: vocabulary,
      readingQuestion: readingQuestion,
      busy: busy ?? this.busy,
      lastRedoCorrect: clearRedo ? null : (lastRedoCorrect ?? this.lastRedoCorrect),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller for the mistake detail page.
class MistakeDetailController
    extends FamilyAsyncNotifier<MistakeDetailState, int> {
  @override
  Future<MistakeDetailState> build(int mistakeId) async {
    final MistakeRepository repository =
        await ref.read(mistakeRepositoryProvider.future);
    final Mistake? mistake = await repository.byId(mistakeId);
    if (mistake == null) {
      throw const NotFoundException('MISTAKE_NOT_FOUND', '未找到该错题。');
    }

    Vocabulary? vocabulary;
    ReadingQuestion? readingQuestion;
    if (mistake.refType == RefType.vocabulary && mistake.refId != null) {
      vocabulary = await (await ref.read(vocabularyRepositoryProvider.future))
          .byId(mistake.refId!);
    } else if (mistake.refType == RefType.reading && mistake.refId != null) {
      readingQuestion = await (await ref.read(readingRepositoryProvider.future))
          .questionById(mistake.refId!);
    }

    return MistakeDetailState(
      mistake: mistake,
      vocabulary: vocabulary,
      readingQuestion: readingQuestion,
    );
  }

  /// Reloads the mistake (e.g. after the content changed).
  Future<void> refresh() async {
    state = AsyncData<MistakeDetailState>(await build(arg));
  }

  /// Grades a redo [answer] and evolves the mistake's mastery (§5.7).
  Future<void> redo(String answer) async {
    final MistakeDetailState? current = state.valueOrNull;
    if (current == null || current.busy) {
      return;
    }
    state = AsyncData<MistakeDetailState>(
      current.copyWith(busy: true, clearRedo: true, clearError: true),
    );
    try {
      final SubmitAnswerUseCase useCase =
          await ref.read(submitAnswerUseCaseProvider.future);
      final Mistake mistake = current.mistake;

      final SubmitAnswerResult result;
      if (mistake.refType == RefType.reading && current.readingQuestion != null) {
        result = await useCase.submitReading(
          userId: AppConstants.localUserId,
          question: current.readingQuestion!,
          userAnswer: answer,
          isRedo: true,
          mistakeId: arg,
        );
      } else if (mistake.refType == RefType.vocabulary && current.vocabulary != null) {
        // Redo a word by producing it from its Chinese meaning.
        result = await useCase.submitVocabulary(
          userId: AppConstants.localUserId,
          vocabularyId: current.vocabulary!.id ?? mistake.refId ?? 0,
          kind: VocabQuestionKind.meaningToWord,
          expected: current.vocabulary!.word,
          actual: answer,
          isRedo: true,
          mistakeId: arg,
        );
      } else {
        state = AsyncData<MistakeDetailState>(
          current.copyWith(busy: false, error: AppStrings.errorGeneric),
        );
        return;
      }

      final MistakeRepository repository =
          await ref.read(mistakeRepositoryProvider.future);
      final Mistake? reloaded = await repository.byId(arg);
      state = AsyncData<MistakeDetailState>(
        current.copyWith(
          mistake: reloaded ?? current.mistake,
          busy: false,
          lastRedoCorrect: result.isCorrect,
          clearError: true,
        ),
      );
      notifyDataChanged(ref);
    } on Object catch (error, stackTrace) {
      appLogger.warning('Mistake redo failed.', error, stackTrace);
      state = AsyncData<MistakeDetailState>(
        current.copyWith(busy: false, error: failureFromException(error).message),
      );
    }
  }
}

/// Provider for the mistake detail controller, keyed by mistake id.
final AsyncNotifierProviderFamily<MistakeDetailController, MistakeDetailState,
        int> mistakeDetailControllerProvider =
    AsyncNotifierProvider.family<MistakeDetailController, MistakeDetailState,
        int>(MistakeDetailController.new);
