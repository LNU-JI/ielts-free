import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/router.dart';
import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/features/settings/application/settings_controller.dart';

/// Root application widget.
///
/// Binds the [GoRouter] (from [routerProvider]) to a [MaterialApp.router] and
/// applies the user's theme mode (PRD Q-6) and font-size scale (BRIEF §82/§85).
/// Both preferences are stored locally and read through [themeModeProvider] /
/// [fontScaleProvider], so changing them in Settings updates the whole app.
class IeltsFreeApp extends ConsumerWidget {
  const IeltsFreeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final double fontScale = ref.watch(fontScaleProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        // Apply the global font-size scale on top of the design tokens.
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(fontScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
