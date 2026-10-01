import 'package:flutter/material.dart';
import 'package:movie_explorer/appUI/home/movie_player.dart';
import 'package:movie_explorer/theme/app_colors.dart';
import 'package:movie_explorer/theme/app_spacing.dart';

/// A "Continue Watching" rail card, built from a WatchHistoryService
/// entry. Tapping it re-opens the player at the same title/episode.
///
/// Note: because playback happens in a third-party embedded player the
/// app doesn't control, there's no real playback percentage available —
/// so this shows a "Recently watched" label rather than a fabricated
/// progress bar.
class ContinueWatchingCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback? onRemove;

  const ContinueWatchingCard({required this.entry, this.onRemove, super.key});

  @override
  Widget build(BuildContext context) {
    final String title = entry['title'] ?? '';
    final String? backdrop = entry['backdrop_path'] ?? entry['poster_path'];
    final String imageUrl = backdrop != null
        ? 'https://image.tmdb.org/t/p/w500$backdrop'
        : '';
    final bool isTv = entry['is_tv'] == true;
    final int? season = entry['season'];
    final int? episode = entry['episode'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MoviePlayerScreen(
              tmdbId: entry['id'],
              title: title,
              isTv: isTv,
              season: season ?? 1,
              episode: episode ?? 1,
              posterPath: entry['poster_path'],
              backdropPath: entry['backdrop_path'],
              voteAverage: entry['vote_average'],
            ),
          ),
        );
      },
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(color: AppColors.surfaceElevated),
                      )
                    else
                      Container(color: AppColors.surfaceElevated),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow, color: Colors.black),
                      ),
                    ),
                    if (onRemove != null)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: onRemove,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 15),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 13),
            ),
            if (isTv && season != null && episode != null)
              Text(
                "S$season E$episode",
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
