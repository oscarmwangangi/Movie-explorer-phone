import 'package:flutter/material.dart';
import 'package:movie_explorer/theme/app_colors.dart';
import 'package:movie_explorer/theme/app_spacing.dart';
import 'package:movie_explorer/appUI/home/movie_details.dart';
import 'package:movie_explorer/appUI/services/favorites_service.dart';

/// A poster card used across Home rails, grids, and search results.
///
/// On mouse-driven platforms (desktop/web) hovering scales the card up
/// slightly and reveals a dark overlay with a play affordance. On
/// keyboard/D-pad (TV remote) navigation, the same overlay appears when
/// the card receives focus, with a visible focus ring so it stays
/// identifiable from a distance. On touch devices neither hover nor
/// focus fires, so the card behaves exactly as a plain tap target.
class Moviecard extends StatefulWidget {
  final dynamic movie;

  const Moviecard({this.movie, super.key});

  @override
  State<Moviecard> createState() => _MoviecardState();
}

class _MoviecardState extends State<Moviecard> {
  bool isFavorite = false;
  bool _hovering = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    if (widget.movie == null) return;
    final status = await FavoritesService.isFavorite(widget.movie['id']);
    if (mounted) {
      setState(() => isFavorite = status);
    }
  }

  Future<void> _toggleFavorite() async {
    if (isFavorite) {
      await FavoritesService.removeFavorite(widget.movie['id']);
    } else {
      await FavoritesService.addFavorite(widget.movie);
    }
    if (mounted) {
      setState(() => isFavorite = !isFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFavorite ? "Added to My List" : "Removed from My List"),
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.surface,
        ),
      );
    }
  }

  void _openDetails(String heroTag) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailsScreen(movie: widget.movie, heroTag: heroTag),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;

    if (movie == null) {
      return Container(
        width: 130,
        height: 195,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
      );
    }

    final String? posterPath = movie['poster_path'];
    final String imageUrl = posterPath != null
        ? 'https://image.tmdb.org/t/p/w500$posterPath'
        : 'https://image.tmdb.org/t/p/w500/9SSEUrSqhljBMzRe4aBTh17rUaC.jpg';

    final String heroTag = 'movie_${movie['id']}_${UniqueKey()}';
    final String title = movie['title'] ?? movie['name'] ?? '';
    final double rating = (movie['vote_average'] as num?)?.toDouble() ?? 0;
    final bool highlighted = _hovering || _focused;

    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              onTap: () => _openDetails(heroTag),
              onFocusChange: (f) => setState(() => _focused = f),
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: AnimatedScale(
                scale: highlighted ? 1.06 : 1.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: _focused
                          ? Border.all(color: AppColors.focusRing, width: 2.5)
                          : Border.all(color: Colors.transparent, width: 2.5),
                      boxShadow: highlighted
                          ? [const BoxShadow(color: Colors.black87, blurRadius: 16, offset: Offset(0, 6))]
                          : [],
                    ),
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Hero(
                            tag: heroTag,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: AppColors.surfaceElevated,
                                  child: const Icon(Icons.movie, color: Colors.white24),
                                ),
                              ),
                            ),
                          ),

                          // Hover/focus overlay: dark gradient + play affordance.
                          IgnorePointer(
                            child: AnimatedOpacity(
                              opacity: highlighted ? 1 : 0,
                              duration: const Duration(milliseconds: 150),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                                      stops: const [0.3, 1.0],
                                    ),
                                  ),
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.play_arrow, color: Colors.black, size: 20),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Quick add/remove favorite button, corner badge.
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: _toggleFavorite,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: isFavorite ? AppColors.accent : Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 14),
          ),
          Row(
            children: [
              const Icon(Icons.star, color: AppColors.rating, size: 14),
              const SizedBox(width: 4),
              Text(
                rating.toStringAsFixed(1),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
