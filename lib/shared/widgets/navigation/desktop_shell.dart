import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/shared/widgets/navigation/nav_destinations.dart';

/// Desktop navigation shell: a left sidebar ([NavigationRail]) around the
/// current page (`child`).
///
/// Rendered by `AppShell` whenever the window is at least
/// `AppBreakpoints.desktop` wide. The selected index is derived from the current
/// route (nested routes such as `/vocabulary/:id` highlight their parent entry);
/// a location with no sidebar counterpart simply highlights nothing.
/// Planned V0.2 destinations (Listening / Writing / Speaking / Statistics) are
/// shown greyed out with a "V0.2" badge and are not navigable (PRD Q-7).
class DesktopShell extends StatelessWidget {
  const DesktopShell({super.key, required this.child});

  /// The page content for the active route.
  final Widget child;

  int? _selectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    final int index = desktopDestinations.indexWhere(
      (NavDestination d) =>
          location == d.route || location.startsWith('${d.route}/'),
    );
    return index < 0 ? null : index;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int? selectedIndex = _selectedIndex(context);
    final bool extended = MediaQuery.sizeOf(context).width >= 1200;

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          NavigationRail(
            extended: extended,
            selectedIndex: selectedIndex,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            onDestinationSelected: (int index) {
              final NavDestination destination = desktopDestinations[index];
              if (destination.isComingSoon) {
                return;
              }
              if (destination.route ==
                  GoRouterState.of(context).matchedLocation) {
                return;
              }
              context.go(destination.route);
            },
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Icon(
                Icons.school,
                color: theme.colorScheme.primary,
                size: 28,
              ),
            ),
            destinations: <NavigationRailDestination>[
              for (final NavDestination d in desktopDestinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(
                    d.isComingSoon
                        ? '${d.label} · ${AppStrings.comingSoon}'
                        : d.label,
                    style: d.isComingSoon
                        ? theme.textTheme.labelMedium?.copyWith(
                            color: context.palette.muted,
                          )
                        : null,
                  ),
                ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
