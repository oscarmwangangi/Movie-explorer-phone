import 'package:flutter/material.dart';

/// Screen-size tiers used throughout the app so every screen reasons
/// about "mobile / tablet / desktop / large desktop-TV" the same way,
/// instead of each widget inventing its own width checks.
enum ScreenTier { mobile, tablet, desktop, tv }

class AppBreakpoints {
  AppBreakpoints._();

  static const double tablet = 600;
  static const double desktop = 1024;
  static const double tv = 1600;

  /// Maximum width the main content column ever grows to, even on an
  /// ultra-wide monitor or a very large TV, so rows of cards and text
  /// don't stretch uncomfortably edge-to-edge.
  static const double maxContentWidth = 1600;

  static ScreenTier tierOf(BuildContext context) => tierForWidth(MediaQuery.of(context).size.width);

  static ScreenTier tierForWidth(double width) {
    if (width >= tv) return ScreenTier.tv;
    if (width >= desktop) return ScreenTier.desktop;
    if (width >= tablet) return ScreenTier.tablet;
    return ScreenTier.mobile;
  }

  static bool isDesktopOrTV(BuildContext context) {
    final tier = tierOf(context);
    return tier == ScreenTier.desktop || tier == ScreenTier.tv;
  }

  /// Picks a value based on the current screen tier. Any tier you don't
  /// specify falls back to the next-smallest one you did specify.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
    T? tv,
  }) {
    switch (tierOf(context)) {
      case ScreenTier.tv:
        return tv ?? desktop ?? tablet ?? mobile;
      case ScreenTier.desktop:
        return desktop ?? tablet ?? mobile;
      case ScreenTier.tablet:
        return tablet ?? mobile;
      case ScreenTier.mobile:
        return mobile;
    }
  }

  /// Target width for a poster-card grid cell at the current screen
  /// tier. Feed this into SliverGridDelegateWithMaxCrossAxisExtent so
  /// column count grows naturally with window width:
  /// mobile ≈ 2–3 cols, tablet ≈ 3–5, desktop ≈ 5–7, TV ≈ 6–8+.
  static double gridCardExtent(BuildContext context) {
    return value(context, mobile: 150, tablet: 160, desktop: 180, tv: 220);
  }

  /// Height for the Home screen's hero banner.
  static double heroHeight(BuildContext context) {
    return value(context, mobile: 460, tablet: 520, desktop: 620, tv: 720);
  }
}
