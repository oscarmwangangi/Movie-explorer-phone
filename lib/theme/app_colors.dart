import 'package:flutter/material.dart';

/// Centralized color palette for the app's cinematic streaming-platform
/// look. Import this instead of hardcoding hex colors in widgets.
class AppColors {
  AppColors._();

  /// Deep near-black background used behind every screen.
  static const Color background = Color(0xFF0A0A0C);

  /// Slightly lighter surface used for cards, sheets, and the nav bar.
  static const Color surface = Color(0xFF16161A);

  /// A step lighter still, for elements sitting on top of [surface]
  /// (e.g. chips, secondary buttons, skeleton shimmer base).
  static const Color surfaceElevated = Color(0xFF232328);

  /// Primary accent, used sparingly for the Play button, active states,
  /// and focus rings. A restrained crimson rather than the previous
  /// bright orange, closer to a premium streaming-app accent.
  static const Color accent = Color(0xFFE22C3E);
  static const Color accentDim = Color(0xFF9A1F2C);

  /// Rating-star gold, kept separate from the accent color.
  static const Color rating = Color(0xFFFFC107);

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA8A8AE);
  static const Color textMuted = Color(0xFF6E6E76);

  static const Color divider = Color(0x1AFFFFFF); // white 10%

  /// Gradient used under hero backdrops and card overlays so text stays
  /// readable regardless of the underlying image.
  static const List<Color> scrimVertical = [
    Colors.transparent,
    Color(0xCC0A0A0C),
    Color(0xFF0A0A0C),
  ];

  static const List<Color> scrimBottomOnly = [
    Colors.transparent,
    Color(0xE60A0A0C),
  ];

  /// Focus ring color for keyboard / D-pad (TV remote) navigation.
  static const Color focusRing = Color(0xFFFFFFFF);
}
