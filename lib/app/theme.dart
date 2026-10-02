/// Design tokens and Material 3 themes for IELTS Free.
///
/// All colors, spacing, radii and text styles are defined here as tokens. Pages
/// must never hard-code a color or a spacing value (see
/// docs/ARCHITECTURE-v0.1.md §2.4 / §9.5). Use `AppColors` / `ColorScheme` and
/// the `AppSpacing` / `AppRadius` / `AppTextStyles` constants instead.
library;

import 'package:flutter/material.dart';

/// Color tokens (PRD Q-3 default palette), with light and dark variants.
abstract final class AppColors {
  // Light
  static const Color primaryLight = Color(0xFF1E3A5F); // brand deep blue
  static const Color secondaryLight = Color(0xFF2F6FED); // interactive accent
  static const Color backgroundLight = Color(0xFFFFFFFF); // page background
  static const Color surfaceLight = Color(0xFFF5F7FA); // card / section
  static const Color successLight = Color(0xFF2E7D32); // correct / mastered
  static const Color warningLight = Color(0xFFED6C02); // notice / due soon
  static const Color errorLight = Color(0xFFD32F2F); // error / unknown
  static const Color textLight = Color(0xFF1A1C1E); // primary text
  static const Color mutedLight = Color(0xFF5F6368); // secondary text

  // Dark
  static const Color primaryDark = Color(0xFF8FB4E0);
  static const Color secondaryDark = Color(0xFF7EA6FF);
  static const Color backgroundDark = Color(0xFF121417);
  static const Color surfaceDark = Color(0xFF1E2126);
  static const Color successDark = Color(0xFF66BB6A);
  static const Color warningDark = Color(0xFFFFB74D);
  static const Color errorDark = Color(0xFFEF5350);
  static const Color textDark = Color(0xFFE6E8EB);
  static const Color mutedDark = Color(0xFF9AA0A6);

  /// Content color placed on top of `primary` surfaces.
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color onPrimaryDark = Color(0xFF0B1016);
}

/// Spacing scale (logical pixels).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner-radius scale (logical pixels).
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
}

/// Text styles. Body text is 15–16 px; headings are graded. A global font-size
/// scale factor is applied on top of these in [AppTheme].
abstract final class AppTextStyles {
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );
  static const TextStyle headline = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const TextStyle titleMedium = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );
  static const TextStyle titleSmall = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    height: 1.5,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 15,
    height: 1.5,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    height: 1.45,
  );
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.4,
  );
}

/// Semantic colors that [ColorScheme] does not model (success / warning /
/// muted). Exposed as a [ThemeExtension] so widgets can read them from
/// `Theme.of(context)` without hard-coding values.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.success,
    required this.warning,
    required this.muted,
  });

  final Color success;
  final Color warning;
  final Color muted;

  @override
  AppPalette copyWith({
    Color? success,
    Color? warning,
    Color? muted,
  }) {
    return AppPalette(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      muted: muted ?? this.muted,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }
    return AppPalette(
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      muted: Color.lerp(muted, other.muted, t) ?? muted,
    );
  }
}

/// Builds the light and dark [ThemeData] from the design tokens above.
abstract final class AppTheme {
  /// Light theme (used by default and when the system is in light mode).
  static ThemeData get light => _build(Brightness.light);

  /// Dark theme.
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;

    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: isLight ? AppColors.primaryLight : AppColors.primaryDark,
      brightness: brightness,
      primary: isLight ? AppColors.primaryLight : AppColors.primaryDark,
      secondary: isLight ? AppColors.secondaryLight : AppColors.secondaryDark,
      surface: isLight ? AppColors.backgroundLight : AppColors.backgroundDark,
      error: isLight ? AppColors.errorLight : AppColors.errorDark,
    );

    final AppPalette palette = AppPalette(
      success: isLight ? AppColors.successLight : AppColors.successDark,
      warning: isLight ? AppColors.warningLight : AppColors.warningDark,
      muted: isLight ? AppColors.mutedLight : AppColors.mutedDark,
    );

    final Color scaffoldBackground =
        isLight ? AppColors.backgroundLight : AppColors.backgroundDark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: _textTheme(),
      extensions: <ThemeExtension<dynamic>>[palette],
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: AppTextStyles.titleSmall,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle:
            const WidgetStatePropertyAll<TextStyle>(AppTextStyles.caption),
      ),
    );
  }

  /// Maps the token text styles onto Material's named [TextTheme] slots so that
  /// default widgets inherit the project's typography.
  static TextTheme _textTheme() {
    return const TextTheme(
      displayLarge: AppTextStyles.displayLarge,
      headlineMedium: AppTextStyles.headline,
      titleLarge: AppTextStyles.titleLarge,
      titleMedium: AppTextStyles.titleMedium,
      titleSmall: AppTextStyles.titleSmall,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.label,
      labelMedium: AppTextStyles.caption,
    );
  }
}

/// Convenience accessor for the semantic palette from a [BuildContext].
extension AppPaletteX on BuildContext {
  /// The current theme's [AppPalette] (success / warning / muted colors).
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ??
      const AppPalette(
        success: AppColors.successLight,
        warning: AppColors.warningLight,
        muted: AppColors.mutedLight,
      );
}

/// Project text-style tokens exposed on [TextTheme].
///
/// Material 3's [TextTheme] has no `caption`, `label` or `headline` member (the
/// first was removed in the M2→M3 migration, the other two never existed), yet
/// the design tokens define all three. This extension maps them onto the same
/// [AppTextStyles] constants that [AppTheme] feeds into [TextTheme], so widgets
/// can keep writing `Theme.of(context).textTheme.caption` without importing the
/// token class directly — and always get the project's typography rather than
/// an ad-hoc style.
extension AppTextThemeX on TextTheme {
  /// 24 px, bold — page-level heading.
  TextStyle get headline => AppTextStyles.headline;

  /// 13 px, medium — control / chip label.
  TextStyle get label => AppTextStyles.label;

  /// 12 px — supporting caption text.
  TextStyle get caption => AppTextStyles.caption;
}
