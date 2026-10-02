/// Convenience accessors that shorten the most common `Theme.of(context)` /
/// `MediaQuery.of(context)` lookups used throughout the presentation layer.
///
/// Keeping these here (instead of repeating `Theme.of(context).…` in every
/// widget) makes the pages read cleanly and gives us a single place to change
/// how theme / size information is obtained (docs/ARCHITECTURE-v0.1.md §3.5).
///
/// Note: `.palette` is provided by [AppPaletteX] in `app/theme.dart`; this file
/// adds the remaining shortcuts and does not redefine it.
library;

import 'package:flutter/material.dart';

import 'package:ielts_free/app/responsive.dart';
import 'package:ielts_free/app/theme.dart';

/// Theme / layout shortcuts for a [BuildContext].
extension AppContextX on BuildContext {
  /// The active [ThemeData].
  ThemeData get theme => Theme.of(this);

  /// The active [ColorScheme].
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// The active [TextTheme].
  TextTheme get texts => Theme.of(this).textTheme;

  /// Semantic palette (success / warning / muted) from [AppPaletteX].
  AppPalette get paletteColors => palette;

  /// Current window width in logical pixels.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Whether the desktop shell layout should be used (`width >= 900`).
  bool get isDesktopLayout => AppBreakpoints.isDesktop(this);

  /// Whether the mobile shell layout should be used (`width < 900`).
  bool get isMobileLayout => AppBreakpoints.isMobile(this);
}
