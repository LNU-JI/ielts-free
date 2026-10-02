import 'package:flutter/material.dart';

import 'package:ielts_free/app/responsive.dart';
import 'package:ielts_free/app/theme.dart';

/// A responsive layout helper.
///
/// - **Mobile** (`width < 900`): renders a single column ([mobile]).
/// - **Desktop** (`width >= 900`): renders two panes — [desktopSide] on the
///   left and [desktopMain] on the right — with a [sideFlex]/[mainFlex] split
///   (default 55 / 45, matching the Reading page of PRD §5).
///
/// When [desktopSide] is omitted the desktop layout falls back to [mobile]
/// centred in a bounded column, which keeps content readable on wide windows.
class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({
    super.key,
    required this.mobile,
    this.desktopSide,
    this.desktopMain,
    this.sideFlex = 55,
    this.mainFlex = 45,
    this.maxContentWidth = 720,
  });

  /// The single-column layout used on mobile.
  final Widget mobile;

  /// The left pane on desktop.
  final Widget? desktopSide;

  /// The right pane on desktop.
  final Widget? desktopMain;

  /// Flex of the left pane (desktop only).
  final int sideFlex;

  /// Flex of the right pane (desktop only).
  final int mainFlex;

  /// Max width used when only [mobile] is provided (desktop, single column).
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    if (!AppBreakpoints.isDesktop(context)) {
      return mobile;
    }

    final Widget? side = desktopSide;
    final Widget? main = desktopMain;
    if (side == null || main == null) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: mobile,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(flex: sideFlex, child: side),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(flex: mainFlex, child: main),
      ],
    );
  }
}

/// A centred, width-bounded page container.
///
/// Keeps long forms (Onboarding, Settings) comfortable on desktop while using
/// the full width on mobile.
class ContentContainer extends StatelessWidget {
  const ContentContainer({
    super.key,
    required this.child,
    this.maxWidth = 640,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  /// Page content.
  final Widget child;

  /// Maximum content width on wide windows.
  final double maxWidth;

  /// Outer padding.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
