import 'package:flutter/material.dart';
import 'package:movie_explorer/appUI/home/movie_details.dart';
import 'package:movie_explorer/appUI/home/movie_player.dart';
import 'package:movie_explorer/appUI/services/favorites_service.dart';
import 'package:movie_explorer/theme/app_breakpoints.dart';
import 'package:movie_explorer/theme/app_colors.dart';

/// Large cinematic hero shown at the top of the Home screen, built from
/// one of the existing TMDB "trending" results — no new API calls.
class HeroBanner extends StatefulWidget {
  final dynamic movie;

  const HeroBanner({required this.movie, super.key});

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final movie = widget.movie;
    if (movie == null || movie['id'] == null) return;
    final status = await FavoritesService.isFavorite(movie['id']);
    if (mounted) setState(() => isFavorite = status);
  }

  Future<void> _toggleFavorite() async {
    final movie = widget.movie;
    if (isFavorite) {
      await FavoritesService.removeFavorite(movie['id']);
    } else {
      await FavoritesService.addFavorite(movie);
    }
    if (mounted) setState(() => isFavorite = !isFavorite);
  }

  @override
  void didUpdateWidget(covariant HeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movie?['id'] != widget.movie?['id']) {
      _controller.forward(from: 0);
      _checkFavorite();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final bool isTv = movie['name'] != null && movie['title'] == null;
    final String title = movie['title'] ?? movie['name'] ?? '';
    final String overview = movie['overview'] ?? '';
    final double rating = (movie['vote_average'] as num?)?.toDouble() ?? 0;
    final String year = (movie['release_date'] ?? movie['first_air_date'] ?? '').toString().split('-').first;
    final String? backdropPath = movie['backdrop_path'] ?? movie['poster_path'];
    final String imageUrl = backdropPath != null
        ? 'https://image.tmdb.org/t/p/w1280$backdropPath'
        : '';

    final double height = AppBreakpoints.heroHeight(context);
    final bool wide = AppBreakpoints.isDesktopOrTV(context);

    return FadeTransition(
      opacity: _fade,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Backdrop image.
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(color: AppColors.surface),
              )
            else
              Container(color: AppColors.surface),

            // Gradient scrim so text stays readable.
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: AppColors.scrimVertical,
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Colors.transparent, Color(0x990A0A0C)],
                ),
              ),
            ),

            // Content.
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 640 : double.infinity),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: wide ? 44 : 28,
                          height: 1.05,
                          shadows: const [Shadow(blurRadius: 12, color: Colors.black87)],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.star, color: AppColors.rating, size: 18),
                          const SizedBox(width: 4),
                          Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 14),
                          if (year.isNotEmpty) Text(year, style: const TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(width: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.textSecondary),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isTv ? "TV" : "MOVIE",
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        overview,
                        maxLines: wide ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MoviePlayerScreen(
                                    tmdbId: movie['id'],
                                    title: title,
                                    isTv: isTv,
                                    posterPath: movie['poster_path'],
                                    backdropPath: movie['backdrop_path'],
                                    voteAverage: movie['vote_average'],
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.play_arrow, color: Colors.black),
                            label: const Text("Play"),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MovieDetailsScreen(movie: movie),
                                ),
                              );
                            },
                            icon: const Icon(Icons.info_outline),
                            label: const Text("More Info"),
                          ),
                          const SizedBox(width: 12),
                          _CircleIconButton(
                            icon: isFavorite ? Icons.check : Icons.add,
                            onTap: _toggleFavorite,
                            tooltip: isFavorite ? "In My List" : "Add to My List",
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _CircleIconButton({required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.4),
            border: Border.all(color: Colors.white54),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
