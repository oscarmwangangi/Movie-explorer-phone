import 'package:flutter/material.dart';
import 'package:movie_explorer/theme/app_colors.dart';
import 'package:movie_explorer/appUI/home/movie_details.dart';
import 'package:movie_explorer/appUI/widget/skeleton.dart';

class searchExpandedWidget extends StatelessWidget {
  final List movies;
  final bool isLoading;

  const searchExpandedWidget({
    super.key,
    required this.movies,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: isLoading
          ? ListView.builder(
              itemCount: 6,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Skeleton(width: 60, height: 90, borderRadius: 8),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Skeleton(width: 150, height: 16),
                            SizedBox(height: 8),
                            Skeleton(width: 50, height: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          : movies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search, size: 56, color: AppColors.textMuted),
                      const SizedBox(height: 16),
                      const Text(
                        "Search for your favorite movies and TV shows",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: movies.length,
                  padding: const EdgeInsets.only(bottom: 100),
                  itemBuilder: (context, index) {
                    
                    var movie = movies[index];
                    String poster = movie['poster_path'] != null
                        ? "https://image.tmdb.org/t/p/w200${movie['poster_path']}"
                        : "https://image.tmdb.org/t/p/w200/9SSEUrSqhljBMzRe4aBTh17rUaC.jpg";

                    final String heroTag = 'search_movie_${movie['id']}';
                    final bool isTv = movie['media_type'] == 'tv' || (movie['name'] != null && movie['title'] == null);
                    final double rating = (movie['vote_average'] as num?)?.toDouble() ?? 0;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MovieDetailsScreen(movie: movie, heroTag: heroTag),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Hero(
                              tag: heroTag,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(poster, width: 60, height: 90, fit: BoxFit.cover),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    movie["title"] ?? movie["name"] ?? "Unknown Title",
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: AppColors.textMuted),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isTv ? "TV" : "MOVIE",
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.star, color: AppColors.rating, size: 13),
                                      const SizedBox(width: 3),
                                      Text(rating.toStringAsFixed(1), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                      const SizedBox(width: 8),
                                      Text(
                                        (movie["release_date"] ?? movie["first_air_date"])?.toString().split('-')[0] ?? "N/A",
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary, size: 14),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
