import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/features/vocabulary/presentation/widgets/vocabulary_detail_pane.dart';
import 'package:ielts_free/features/vocabulary/presentation/widgets/vocabulary_list_pane.dart';
import 'package:ielts_free/shared/extensions/context_extensions.dart';

/// Vocabulary detail (desktop shell route `/vocabulary/:id`).
///
/// Desktop: keeps the list visible on the left (55%) and shows the word on the
/// right (45%). Mobile: shows only the word card and action bar.
class VocabularyDetailPage extends StatelessWidget {
  const VocabularyDetailPage({super.key, required this.vocabularyId});

  /// Id of the vocabulary entry (from the read-only content database).
  final int vocabularyId;

  @override
  Widget build(BuildContext context) {
    if (context.isDesktopLayout) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.vocabularyTitle)),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: 55,
              child: VocabularyListPane(
                selectedId: vocabularyId,
                onSelect: (int id) =>
                    context.go('${AppRoutes.vocabulary}/$id'),
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              flex: 45,
              child: VocabularyDetailPane(vocabularyId: vocabularyId),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.vocabularyTitle)),
      body: VocabularyDetailPane(vocabularyId: vocabularyId),
    );
  }
}
