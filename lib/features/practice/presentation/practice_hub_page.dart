import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/shared/widgets/adaptive_layout.dart';
import 'package:ielts_free/shared/widgets/hub_tile.dart';

/// Mobile "练习" tab hub (mobile shell route `/practice`).
class PracticeHubPage extends StatelessWidget {
  const PracticeHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navPractice)),
      body: ContentContainer(
        maxWidth: 720,
        child: ListView(
          children: <Widget>[
            Text(
              AppStrings.practiceHubSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.palette.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            HubTile(
              icon: Icons.quiz_outlined,
              title: AppStrings.practiceHubVocabulary,
              subtitle: AppStrings.vocabularyPracticeTitle,
              onTap: () => context.go(AppRoutes.vocabularyPractice),
            ),
            const SizedBox(height: AppSpacing.md),
            HubTile(
              icon: Icons.article_outlined,
              title: AppStrings.practiceHubReading,
              subtitle: AppStrings.readingTitle,
              onTap: () => context.go(AppRoutes.reading),
            ),
            const SizedBox(height: AppSpacing.md),
            HubTile(
              icon: Icons.error_outline,
              title: AppStrings.practiceHubMistakes,
              subtitle: AppStrings.mistakesTitle,
              onTap: () => context.go(AppRoutes.mistakes),
            ),
          ],
        ),
      ),
    );
  }
}
