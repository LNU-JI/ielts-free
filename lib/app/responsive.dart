import 'package:flutter/widgets.dart';

import 'constants.dart';

/// Responsive breakpoint helpers.
///
/// The app has two navigation shells:
/// - **mobile** (width `< 900`) — bottom [NavigationBar];
/// - **desktop** (width `>= 900`) — left sidebar.
///
/// The same threshold is used both by the router (to pick a landing route) and
/// by the shells themselves.
abstract final class AppBreakpoints {
  /// Width (logical pixels) at or above which the desktop layout is used.
  static const double desktop = AppConstants.desktopBreakpoint;

  /// Whether the current window is wide enough for the desktop shell.
  static bool isDesktop(BuildContext context) =>
      isDesktopWidth(MediaQuery.sizeOf(context).width);

  /// Whether the current window should use the mobile shell.
  static bool isMobile(BuildContext context) => !isDesktop(context);

  /// Pure width check, usable where a [BuildContext] is not available
  /// (for example inside a `go_router` redirect).
  static bool isDesktopWidth(double width) => width >= desktop;
}
