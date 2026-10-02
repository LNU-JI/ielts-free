import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/shared/widgets/placeholder_page.dart';

/// V0.2 placeholder for Statistics (desktop shell route `/statistics`).
class StatisticsPlaceholderPage extends StatelessWidget {
  const StatisticsPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: AppStrings.navStatistics,
      icon: Icons.insights_outlined,
      message: '${AppStrings.navStatistics} 将在 ${AppStrings.comingSoon} 版本提供。'
          '\n${AppStrings.placeholderMessage}',
    );
  }
}
