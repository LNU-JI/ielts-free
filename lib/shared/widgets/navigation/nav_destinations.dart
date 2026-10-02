import 'package:flutter/material.dart';

import 'package:ielts_free/app/strings.dart';

/// A single navigation entry, shared by both shells.
@immutable
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
    this.isComingSoon = false,
  });

  /// Visible label (from `strings.dart`).
  final String label;

  /// Icon shown when the destination is not selected.
  final IconData icon;

  /// Icon shown when the destination is selected.
  final IconData selectedIcon;

  /// Target route path understood by `go_router`.
  final String route;

  /// `true` for planned (V0.2) destinations that are shown but disabled.
  final bool isComingSoon;
}

/// Mobile bottom navigation: 首页 / 学习 / 练习 / 错题 / 我的.
///
/// These routes are provided by the mobile `ShellRoute` in `router.dart`.
const List<NavDestination> mobileDestinations = <NavDestination>[
  NavDestination(
    label: AppStrings.navHome,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    route: '/home',
  ),
  NavDestination(
    label: AppStrings.navLearn,
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
    route: '/learn',
  ),
  NavDestination(
    label: AppStrings.navPractice,
    icon: Icons.edit_note_outlined,
    selectedIcon: Icons.edit_note,
    route: '/practice',
  ),
  NavDestination(
    label: AppStrings.navMistakes,
    icon: Icons.error_outline,
    selectedIcon: Icons.error,
    route: '/mistakes',
  ),
  NavDestination(
    label: AppStrings.navMe,
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    route: '/me',
  ),
];

/// Desktop sidebar entries (BRIEF §6): Home / Learn / Vocabulary / Reading /
/// Listening / Writing / Speaking / Mistakes / Study Plan / Statistics /
/// Settings.
///
/// Listening / Writing / Speaking / Statistics are V0.2 and are shown greyed out
/// with a "V0.2" badge (PRD Q-7).
///
/// NOTE (resolved in T05): the `Learn` and `Mistakes` entries point at routes
/// (`/learn`, `/mistakes`) that are also reachable from the mobile bottom bar.
/// Because both navigation trees now render through the width-adaptive
/// [AppShell], a single sidebar entry maps to the correct layout at any width;
/// the previous two-`ShellRoute` split has been removed.
const List<NavDestination> desktopDestinations = <NavDestination>[
  NavDestination(
    label: AppStrings.navDashboard,
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    route: '/dashboard',
  ),
  NavDestination(
    label: AppStrings.navLearnHub,
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
    route: '/learn',
  ),
  NavDestination(
    label: AppStrings.navVocabulary,
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
    route: '/vocabulary',
  ),
  NavDestination(
    label: AppStrings.navReading,
    icon: Icons.article_outlined,
    selectedIcon: Icons.article,
    route: '/reading',
  ),
  NavDestination(
    label: AppStrings.navListening,
    icon: Icons.headphones_outlined,
    selectedIcon: Icons.headphones,
    route: '/listening',
    isComingSoon: true,
  ),
  NavDestination(
    label: AppStrings.navWriting,
    icon: Icons.edit_outlined,
    selectedIcon: Icons.edit,
    route: '/writing',
    isComingSoon: true,
  ),
  NavDestination(
    label: AppStrings.navSpeaking,
    icon: Icons.record_voice_over_outlined,
    selectedIcon: Icons.record_voice_over,
    route: '/speaking',
    isComingSoon: true,
  ),
  NavDestination(
    label: AppStrings.navMistakesFull,
    icon: Icons.error_outline,
    selectedIcon: Icons.error,
    route: '/mistakes',
  ),
  NavDestination(
    label: AppStrings.navStudyPlan,
    icon: Icons.event_note_outlined,
    selectedIcon: Icons.event_note,
    route: '/study-plan',
  ),
  NavDestination(
    label: AppStrings.navStatistics,
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
    route: '/statistics',
    isComingSoon: true,
  ),
  NavDestination(
    label: AppStrings.navSettings,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    route: '/settings',
  ),
];

/// Fallback bottom-navigation tab for routes that live in the desktop
/// navigation tree and therefore have **no** bottom-bar counterpart.
///
/// Values are indices into [mobileDestinations] (首页 0 / 学习 1 / 练习 2 /
/// 错题 3 / 我的 4). The mapping follows semantic proximity to each tab's
/// domain:
/// - `/dashboard` → 首页 (same `DashboardPage` the `/home` tab shows);
/// - `/vocabulary`, `/reading`, `/listening`, `/writing`, `/speaking` → 学习
///   (the study modules, all reachable from the Learn hub);
/// - `/study-plan`, `/statistics`, `/settings` → 我的 (plan / stats / settings
///   are the profile-scoped screens, reachable from the Me tab on mobile).
const Map<String, int> _desktopFallbackTab = <String, int>{
  '/dashboard': 0,
  '/vocabulary': 1,
  '/reading': 1,
  '/listening': 1,
  '/writing': 1,
  '/speaking': 1,
  '/study-plan': 4,
  '/statistics': 4,
  '/settings': 4,
};

/// Resolves which bottom-navigation tab to highlight for [location].
///
/// A mobile destination matches first (exact path or a nested child such as
/// `/mistakes/12`). When the location belongs to the desktop navigation tree
/// (`/vocabulary/3`, `/settings/about`, `/study-plan`, …) the closest logical
/// parent tab from [_desktopFallbackTab] is used instead, so the bottom bar
/// never shows a stale/incorrect selection.
///
/// A "no selection" state is intentionally **not** used: Flutter's
/// `NavigationBar.selectedIndex` is a required, in-range `int`
/// (`0 <= selectedIndex < destinations.length`), so it cannot express "none".
/// Falling back to the nearest parent tab is therefore both the only valid
/// option and the better UX (it keeps a sensible tab highlighted while the user
/// is in a deeper screen).
int mobileTabIndexFor(String location) {
  for (int i = 0; i < mobileDestinations.length; i++) {
    final String route = mobileDestinations[i].route;
    if (location == route || location.startsWith('$route/')) {
      return i;
    }
  }
  for (final MapEntry<String, int> entry in _desktopFallbackTab.entries) {
    if (location == entry.key || location.startsWith('${entry.key}/')) {
      return entry.value;
    }
  }
  // Unknown location: highlight 首页 rather than crash or mis-highlight.
  return 0;
}
