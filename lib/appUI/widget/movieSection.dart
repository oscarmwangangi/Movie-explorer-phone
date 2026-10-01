import 'package:flutter/material.dart';
import 'package:movie_explorer/theme/app_colors.dart';
import 'package:movie_explorer/appUI/home/category_results.dart';
import 'package:movie_explorer/appUI/widget/moviecard.dart';
import 'package:movie_explorer/appUI/widget/skeleton.dart';

class Moviesection extends StatelessWidget {
  final String title;
  final List movies;
  final bool isLoading;

  /// The key passed to TMDBService.getCategoryPage when "See More" is
  /// tapped, e.g. 'popular movies' or 'tv series'. Defaults to [title]
  /// for sections whose display title already happens to match a valid
  /// category key. Pass this explicitly whenever you want a nicer
  /// display title than the raw category key (see TMDBService.getCategoryPage
  /// for the exact accepted strings) — this keeps "See More" pagination
  /// correct even if the on-screen heading changes.
  final String? categoryType;

  const Moviesection({
    required this.title,
    this.movies = const [],
    this.isLoading = false,
    this.categoryType,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall, // Semi-bold ~18sp
              ),
              if (!isLoading && movies.length > 5)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryResultsScreen(
                          title: title,
                          categoryType: categoryType ?? title,
                          items: movies,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    "See More",
                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 250, // Adjusted to accommodate text below poster
          child: isLoading
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Skeleton(width: 130, height: 195, borderRadius: 12),
                          const SizedBox(height: 8),
                          const Skeleton(width: 100, height: 14),
                          const SizedBox(height: 4),
                          const Skeleton(width: 40, height: 14),
                        ],
                      ),
                    );
                  },
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: movies.length,
                  itemBuilder: (context, index) {
                    return Moviecard(movie: movies[index]);
                  },
                ),
        ),
      ],
    );
  }
}
