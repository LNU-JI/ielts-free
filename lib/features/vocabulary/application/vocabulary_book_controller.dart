/// State provider backing the vocabulary book (browse) page.
///
/// The book reuses the battle-tested [VocabularyListController] (paged loading,
/// topic filter, debounced search) but under its **own provider instance**, so
/// browsing the book never leaks filters into the practice-oriented list page
/// (and vice versa). No controller logic is duplicated.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ielts_free/features/vocabulary/application/vocabulary_list_controller.dart';

/// Independent [VocabularyListController] instance for the vocabulary book.
final AsyncNotifierProvider<VocabularyListController, VocabularyListState>
    vocabularyBookControllerProvider =
    AsyncNotifierProvider<VocabularyListController, VocabularyListState>(
  VocabularyListController.new,
);
