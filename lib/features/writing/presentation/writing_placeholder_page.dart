import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/shared/widgets/placeholder_page.dart';

/// V0.2 placeholder for the Writing module (desktop shell route `/writing`).
class WritingPlaceholderPage extends StatelessWidget {
  const WritingPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: AppStrings.navWriting,
      icon: Icons.edit_outlined,
      message: '${AppStrings.navWriting} 将在 ${AppStrings.comingSoon} 版本提供。'
          '\n${AppStrings.placeholderMessage}',
    );
  }
}
