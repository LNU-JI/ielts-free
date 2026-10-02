/// Provider for the unified answer-persistence use case.
///
/// The use case is the single write path of the adaptive loop (see
/// `submit_answer_usecase.dart`). It is built once per user-database connection
/// and shares the same pure T03 services the rest of the app uses, so the loop
/// and the plan generator can never disagree about an algorithm.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'package:ielts_free/core/providers/database_providers.dart';
import 'package:ielts_free/core/providers/service_providers.dart';
import 'package:ielts_free/core/services/submit_answer_usecase.dart';

/// The shared [SubmitAnswerUseCase].
final FutureProvider<SubmitAnswerUseCase> submitAnswerUseCaseProvider =
    FutureProvider<SubmitAnswerUseCase>((Ref ref) async {
  final Database db = await ref.watch(userDbProvider.future);
  return SubmitAnswerUseCase(
    db: db,
    gradingService: ref.watch(gradingServiceProvider),
    memoryService: ref.watch(memoryServiceProvider),
    skillScoreService: ref.watch(skillScoreServiceProvider),
    difficultyService: ref.watch(difficultyServiceProvider),
    priorityService: ref.watch(priorityServiceProvider),
    masteryService: ref.watch(masteryServiceProvider),
    streakService: ref.watch(streakServiceProvider),
    clock: ref.watch(clockProvider),
  );
});
