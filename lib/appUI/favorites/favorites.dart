import 'package:flutter/material.dart';
import 'package:movie_explorer/appUI/shell/app_scaffold.dart';
import 'package:movie_explorer/appUI/widget/moviecard.dart';
import 'package:movie_explorer/appUI/services/favorites_service.dart';
import 'package:movie_explorer/theme/app_breakpoints.dart';
import 'package:movie_explorer/theme/app_colors.dart';

import 'package:movie_explorer/appUI/widget/skeleton.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  static String id = "favorites_screen";

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List favoriteMovies = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await FavoritesService.getFavorites();
    if (mounted) {
      setState(() {
        favoriteMovies = favorites;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      activeIndex: 3,
      appBar: AppBar(
        title: const Text("My List"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              const SizedBox(height: 10),
              Expanded(
                child: isLoading
                    ? GridView.builder(
                        itemCount: 6,
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: AppBreakpoints.gridCardExtent(context),
                          childAspectRatio: 2 / 3.8,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemBuilder: (context, index) {
                          return const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Skeleton(height: 250, borderRadius: 12),
                              SizedBox(height: 8),
                              Skeleton(width: 120, height: 16),
                              SizedBox(height: 4),
                              Skeleton(width: 60, height: 16),
                            ],
                          );
                        },
                      )
                    : favoriteMovies.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.list_alt, size: 60, color: AppColors.textMuted),
                                const SizedBox(height: 16),
                                const Text(
                                  "Your list is empty",
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 18),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Add movies to see them here",
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            itemCount: favoriteMovies.length,
                            padding: const EdgeInsets.only(bottom: 20),
                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: AppBreakpoints.gridCardExtent(context),
                              childAspectRatio: 2 / 3.8,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemBuilder: (context, index) {
                              return Moviecard(movie: favoriteMovies[index]);
                            },
                          ),
              ),
          ],
        ),
      ),
    );
  }
}
