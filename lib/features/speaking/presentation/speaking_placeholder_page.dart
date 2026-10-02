import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/shared/widgets/placeholder_page.dart';

/// V0.2 placeholder for the Speaking module (desktop shell route `/speaking`).
class SpeakingPlaceholderPage extends StatelessWidget {
  const SpeakingPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: AppStrings.navSpeaking,
      icon: Icons.record_voice_over_outlined,
      message: '${AppStrings.navSpeaking} 将在 ${AppStrings.comingSoon} 版本提供。'
          '\n${AppStrings.placeholderMessage}',
    );
  }
}
