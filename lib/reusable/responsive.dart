import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// Below this width the app uses the original phone-style layout
/// (bottom nav bar, single/double column grids).
/// At or above it, the app switches to a laptop/desktop-style layout
/// (top navigation bar, wider grids, centered content).
/// Kept equal to AppBreakpoints.desktop so the shell's nav switch and
/// each screen's own layout logic change at the same width.
const double kDesktopBreakpoint = 1024;

/// Content is centered and capped at this width on very wide screens
/// (e.g. a maximized window on a large monitor or TV) so text and rows
/// of cards don't stretch uncomfortably edge-to-edge. Matches
/// AppBreakpoints.maxContentWidth used by the Home screen.
const double kMaxContentWidth = 1600;

bool isDesktopWidth(BuildContext context) {
  return MediaQuery.of(context).size.width >= kDesktopBreakpoint;
}

/// True on platforms that don't support the mobile WebView / embedded
/// YouTube player plugins (Windows, Linux). On these, playback screens
/// fall back to opening the link in the system's default browser.
bool get isDesktopPlatform {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isLinux;
}

/// Wraps [child] so it is centered and width-capped on large screens,
/// while behaving exactly like a plain full-width child on phones.
class CenteredContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const CenteredContent({super.key, required this.child, this.maxWidth = kMaxContentWidth});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
