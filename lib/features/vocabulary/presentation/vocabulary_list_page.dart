import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/features/vocabulary/presentation/widgets/vocabulary_list_pane.dart';
import 'package:ielts_free/shared/extensions/context_extensions.dart';
import 'package:ielts_free/shared/widgets/empty_state.dart';

/// Vocabulary list (desktop shell route `/vocabulary`).
///
/// Desktop: a two-column master/detail layout — the list on the left and a
/// "select a word" hint on the right. Mobile: just the list, tapping through to
/// the detail route.
class VocabularyListPage extends StatelessWidget {
  const VocabularyListPage({super.key});

  @override
  Widget build(BuildContext context) {
    void select(int id) => context.go('${AppRoutes.vocabulary}/$id');

    if (context.isDesktopLayout) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.vocabularyTitle)),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: 55,
              child: VocabularyListPane(onSelect: select),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            const Expanded(
              flex: 45,
              child: EmptyState(
                icon: Icons.menu_book_outlined,
                message: AppStrings.vocabularyEmptyHint,
                title: AppStrings.vocabularyTitle,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.vocabularyTitle)),
      body: VocabularyListPane(onSelect: select),
    );
  }
}
