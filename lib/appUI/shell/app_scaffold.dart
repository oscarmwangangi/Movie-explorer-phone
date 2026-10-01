import 'package:flutter/material.dart';
import 'package:movie_explorer/theme/app_colors.dart';
import 'package:movie_explorer/appUI/footer/buildFooter.dart';
import 'package:movie_explorer/appUI/widget/netflix_navbar.dart';
import 'package:movie_explorer/reusable/responsive.dart';

/// A Scaffold that adapts between the original phone layout (bottom nav
/// bar, edge-to-edge content) and a laptop/desktop/TV layout (a premium
/// top navigation bar, content centered and capped in width) based on
/// the available window width. Used by the three top-level tab screens:
/// Home, Search and Favorites.
class AppScaffold extends StatelessWidget {
  final int activeIndex;
  final PreferredSizeWidget? appBar;
  final Widget body;
  final bool constrainBody;

  const AppScaffold({
    super.key,
    required this.activeIndex,
    required this.body,
    this.appBar,
    this.constrainBody = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool desktop = isDesktopWidth(context);
    final Widget content = constrainBody ? CenteredContent(child: body) : body;

    if (!desktop) {
      return Scaffold(
        appBar: appBar,
        bottomNavigationBar: buildFooter(context, activeIndex),
        body: SafeArea(child: content),
      );
    }

    // On desktop/TV widths, the premium top navbar replaces both the
    // per-screen AppBar and the phone's bottom nav bar.
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: NetflixNavbar(activeIndex: activeIndex),
      body: content,
    );
  }
}
