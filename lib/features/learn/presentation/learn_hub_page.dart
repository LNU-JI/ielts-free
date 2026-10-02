import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/shared/widgets/adaptive_layout.dart';
import 'package:ielts_free/shared/widgets/hub_tile.dart';

/// Mobile "学习" tab hub (mobile shell route `/learn`).
///
/// Lists the study modules. Vocabulary and Reading are live in V0.1; Listening /
/// Writing / Speaking are shown greyed out as V0.2 placeholders (PRD Q-7).
class LearnHubPage extends StatelessWidget {
  const LearnHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navLearn)),
      body: ContentContainer(
        maxWidth: 720,
        child: ListView(
          children: <Widget>[
            Text(
              AppStrings.learnHubSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.palette.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            HubTile(
              icon: Icons.menu_book_outlined,
              title: AppStrings.learnHubVocabulary,
              subtitle: AppStrings.vocabularyTitle,
              onTap: () => context.go(AppRoutes.vocabulary),
            ),
            const SizedBox(height: AppSpacing.md),
            HubTile(
              icon: Icons.article_outlined,
              title: AppStrings.learnHubReading,
              subtitle: AppStrings.readingTitle,
              onTap: () => context.go(AppRoutes.reading),
            ),
            const SizedBox(height: AppSpacing.md),
            const HubTile(
              icon: Icons.headphones_outlined,
              title: AppStrings.learnHubListening,
              comingSoon: true,
            ),
            const SizedBox(height: AppSpacing.md),
            const HubTile(
              icon: Icons.edit_outlined,
              title: AppStrings.learnHubWriting,
              comingSoon: true,
            ),
            const SizedBox(height: AppSpacing.md),
            const HubTile(
              icon: Icons.record_voice_over_outlined,
              title: AppStrings.learnHubSpeaking,
              comingSoon: true,
            ),
          ],
        ),
      ),
    );
  }
}
