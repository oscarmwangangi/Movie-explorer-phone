import 'package:flutter/material.dart';
import 'package:movie_explorer/theme/app_colors.dart';
import 'package:movie_explorer/appUI/search/search.dart';
import 'package:movie_explorer/appUI/favorites/favorites.dart';
import 'package:movie_explorer/appUI/home/home.dart';
import 'package:movie_explorer/appUI/movies/movies_screen.dart';
import 'package:movie_explorer/appUI/tv_shows/tv_shows_screen.dart';
import 'package:movie_explorer/authentication/profile.dart';

/// Index scheme shared with NetflixNavbar: 0 Home, 1 Movies, 2 TV
/// Shows, 3 My List, 4 Search, 5 Profile.
Widget buildFooter(BuildContext context, int activeIndex) {
  return Container(
    height: 68,
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _footerItem(context, Icons.home, "Home", activeIndex == 0, () {
          if (activeIndex != 0) Navigator.pushReplacementNamed(context, HomeScreen.id);
        }),
        _footerItem(context, Icons.movie_outlined, "Movies", activeIndex == 1, () {
          if (activeIndex != 1) Navigator.pushReplacementNamed(context, MoviesScreen.id);
        }),
        _footerItem(context, Icons.live_tv_outlined, "TV Shows", activeIndex == 2, () {
          if (activeIndex != 2) Navigator.pushReplacementNamed(context, TVShowsScreen.id);
        }),
        _footerItem(context, Icons.favorite, "My List", activeIndex == 3, () {
          if (activeIndex != 3) Navigator.pushReplacementNamed(context, FavoritesScreen.id);
        }),
        _footerItem(context, Icons.search, "Search", activeIndex == 4, () {
          if (activeIndex != 4) Navigator.pushReplacementNamed(context, SearchScreen.id);
        }),
        _footerItem(context, Icons.person_outline, "Profile", activeIndex == 5, () {
          if (activeIndex != 5) Navigator.pushNamed(context, ProfileScreen.id);
        }),
      ],
    ),
  );
}

Widget _footerItem(BuildContext context, IconData icon, String label, bool isActive, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 22,
          color: isActive ? Colors.white : AppColors.textSecondary,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}
