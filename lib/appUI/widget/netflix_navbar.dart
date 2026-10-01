import 'package:flutter/material.dart';
import 'package:movie_explorer/appUI/favorites/favorites.dart';
import 'package:movie_explorer/appUI/home/home.dart';
import 'package:movie_explorer/appUI/movies/movies_screen.dart';
import 'package:movie_explorer/appUI/tv_shows/tv_shows_screen.dart';
import 'package:movie_explorer/appUI/search/search.dart';
import 'package:movie_explorer/authentication/profile.dart';
import 'package:movie_explorer/theme/app_colors.dart';

/// Premium horizontal navigation bar shown across the top of the app on
/// desktop / large-screen widths, replacing the phone's bottom nav bar.
///
/// Index scheme shared with buildFooter.dart: 0 Home, 1 Movies,
/// 2 TV Shows, 3 My List, 4 Search.
class NetflixNavbar extends StatelessWidget implements PreferredSizeWidget {
  final int activeIndex;

  const NetflixNavbar({required this.activeIndex, super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  void _navigate(BuildContext context, int index) {
    if (index == activeIndex) return;
    final String id = switch (index) {
      0 => HomeScreen.id,
      1 => MoviesScreen.id,
      2 => TVShowsScreen.id,
      3 => FavoritesScreen.id,
      4 => SearchScreen.id,
      _ => HomeScreen.id,
    };
    Navigator.pushReplacementNamed(context, id);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          const Text(
            "MOVIE EXPLORER",
            style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5),
          ),
          const SizedBox(width: 40),
          _NavLink(label: "Home", selected: activeIndex == 0, onTap: () => _navigate(context, 0)),
          _NavLink(label: "Movies", selected: activeIndex == 1, onTap: () => _navigate(context, 1)),
          _NavLink(label: "TV Shows", selected: activeIndex == 2, onTap: () => _navigate(context, 2)),
          _NavLink(label: "My List", selected: activeIndex == 3, onTap: () => _navigate(context, 3)),
          _NavLink(label: "Search", selected: activeIndex == 4, onTap: () => _navigate(context, 4)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, ProfileScreen.id),
            child: const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.surfaceElevated,
              child: Icon(Icons.person, color: Colors.white70, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavLink({required this.label, required this.selected, required this.onTap});

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovering = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bool highlighted = widget.selected || _hovering || _focused;
    return Padding(
      padding: const EdgeInsets.only(right: 28),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Focus(
          onFocusChange: (f) => setState(() => _focused = f),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                widget.label,
                style: TextStyle(
                  color: highlighted ? Colors.white : AppColors.textSecondary,
                  fontWeight: widget.selected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
