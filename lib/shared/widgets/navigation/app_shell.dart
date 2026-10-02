import 'package:flutter/material.dart';

import 'package:ielts_free/app/responsive.dart';
import 'package:ielts_free/shared/widgets/navigation/desktop_shell.dart';
import 'package:ielts_free/shared/widgets/navigation/mobile_shell.dart';

/// Width-adaptive navigation shell shared by every in-shell route.
///
/// The app exposes a **single navigation tree**; this widget decides *how* to
/// render it purely from the current window width (BRIEF §2.3, PRD Q-6):
/// - width `>= AppBreakpoints.desktop` → [DesktopShell] (left [NavigationRail]);
/// - otherwise → [MobileShell] (bottom [NavigationBar]).
///
/// It replaces the previous design, in which the mobile routes (`/home`,
/// `/learn`, `/practice`, `/mistakes`, `/me`) and the desktop routes
/// (`/dashboard`, `/vocabulary`, `/reading`, `/study-plan`, `/settings`, …)
/// lived in **two separate `ShellRoute`s**. That split caused the wrong shell to
/// render whenever a route was opened outside its "own" width class — e.g.
/// `/vocabulary/:id` on a phone rendered the desktop sidebar, and `Mistakes`
/// from the desktop sidebar rendered the mobile bottom bar.
///
/// With a single adaptive shell, every route renders correctly at every width;
/// the two `ShellRoute`s in `router.dart` are kept only to preserve the exact
/// route table (paths, nesting and redirect behaviour are unchanged).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  /// The page content for the active route.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    return AppBreakpoints.isDesktopWidth(width)
        ? DesktopShell(child: child)
        : MobileShell(child: child);
  }
}
