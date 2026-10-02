import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/shared/widgets/navigation/nav_destinations.dart';

/// Mobile navigation shell: a Material 3 bottom [NavigationBar] around the
/// current page (`child`).
///
/// Rendered by `AppShell` whenever the window is narrower than
/// `AppBreakpoints.desktop`. The selected index is resolved by
/// [mobileTabIndexFor], so nested routes (`/mistakes/:id`) highlight their own
/// tab and desktop-tree routes (`/vocabulary`, `/settings`, `/study-plan`, …)
/// fall back to their closest parent tab instead of mis-highlighting 首页.
class MobileShell extends StatelessWidget {
  const MobileShell({super.key, required this.child});

  /// The page content for the active route.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    final int selectedIndex = mobileTabIndexFor(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (int index) {
          final NavDestination destination = mobileDestinations[index];
          if (destination.route == GoRouterState.of(context).matchedLocation) {
            return;
          }
          context.go(destination.route);
        },
        destinations: <Widget>[
          for (final NavDestination d in mobileDestinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
