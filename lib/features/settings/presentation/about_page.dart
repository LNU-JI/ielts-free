import 'package:flutter/material.dart';

import 'package:ielts_free/app/constants.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/shared/widgets/adaptive_layout.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';

/// About page (desktop shell route `/settings/about`).
///
/// Renders the copyright / independence disclaimer **verbatim** as required by
/// the BRIEF (section 56) — do not reword that text — plus short privacy and
/// licensing notes (PRD §6.3 / §8).
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.aboutTitle)),
      body: ContentContainer(
        maxWidth: 720,
        child: ListView(
          children: <Widget>[
            Text(AppStrings.appName, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppStrings.appTagline,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.palette.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Version ${AppConstants.appVersion} (${AppConstants.appBuildNumber})',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.palette.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // The disclaimer must stay verbatim (BRIEF §56).
            SectionCard(
              child: Text(
                AppStrings.aboutDisclaimer,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            const _Note(
              title: AppStrings.settingsPrivacy,
              body: AppStrings.privacySummary,
            ),
            const SizedBox(height: AppSpacing.md),
            const _Note(
              title: AppStrings.settingsLicense,
              body: AppStrings.licenseSummary,
            ),
            const SizedBox(height: AppSpacing.md),
            const _Note(
              title: AppStrings.settingsOpenSource,
              body: AppStrings.openSourceSummary,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// A titled note block.
class _Note extends StatelessWidget {
  const _Note({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
