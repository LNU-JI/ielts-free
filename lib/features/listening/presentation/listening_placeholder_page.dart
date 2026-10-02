import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/shared/widgets/placeholder_page.dart';

/// V0.2 placeholder for the Listening module (desktop shell route `/listening`).
class ListeningPlaceholderPage extends StatelessWidget {
  const ListeningPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: AppStrings.navListening,
      icon: Icons.headphones_outlined,
      message: '${AppStrings.navListening} 将在 ${AppStrings.comingSoon} 版本提供。'
          '\n${AppStrings.placeholderMessage}',
    );
  }
}
