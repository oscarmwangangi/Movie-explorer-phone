import 'dart:math';

import 'package:flutter/material.dart';
import 'package:movie_explorer/appUI/services/favorites_service.dart';
import 'package:movie_explorer/appUI/services/tmdb_service.dart';
import 'package:movie_explorer/appUI/services/watch_history_service.dart';
import 'package:movie_explorer/appUI/shell/app_scaffold.dart';
import 'package:movie_explorer/appUI/widget/continue_watching_card.dart';
import 'package:movie_explorer/appUI/widget/hero_banner.dart';
import 'package:movie_explorer/appUI/widget/movieSection.dart';
import 'package:movie_explorer/appUI/widget/skeleton.dart';
import 'package:movie_explorer/appUI/search/search.dart';
import 'package:movie_explorer/theme/app_breakpoints.dart';
import 'package:movie_explorer/theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static String id = "home_screen";

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List trending = [];
  List popularMovies = [];
  List topRatedMovies = [];
  List upcomingMovies = [];
  List nowPlayingMovies = [];
  List tvSeries = [];
  List topRatedTV = [];
  List horrorMovies = [];
  List kidsMovies = [];
  List actionMovies = [];
  List sciFiMovies = [];
  List documentaries = [];
  List romanceMovies = [];

  List<Map<String, dynamic>> continueWatching = [];
  List myList = [];
  dynamic heroMovie;

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMovies();
    _loadContinueWatchingAndMyList();
  }

  Future<void> _loadContinueWatchingAndMyList() async {
    final history = await WatchHistoryService.getHistory();
    final favorites = await FavoritesService.getFavorites();
    if (mounted) {
      setState(() {
        continueWatching = history;
        myList = favorites;
      });
    }
  }

  Future<void> _fetchMovies() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final results = await Future.wait([
        TMDBService.getTrending(),
        TMDBService.getPopularMovies(),
        TMDBService.getTopRatedMovies(),
        TMDBService.getUpcomingMovies(),
        TMDBService.getNowPlayingMovies(),
        TMDBService.getTVSeries(),
        TMDBService.getTopRatedTVSeries(),
        TMDBService.getHorrorMovies(),
        TMDBService.getKidsMovies(),
        TMDBService.getActionMovies(),
        TMDBService.getSciFiFantasyMovies(),
        TMDBService.getDocumentaries(),
        TMDBService.getRomanceMovies(),
      ]);
      if (mounted) {
        setState(() {
          trending = results[0];
          popularMovies = results[1];
          topRatedMovies = results[2];
          upcomingMovies = results[3];
          nowPlayingMovies = results[4];
          tvSeries = results[5];
          topRatedTV = results[6];
          horrorMovies = results[7];
          kidsMovies = results[8];
          actionMovies = results[9];
          sciFiMovies = results[10];
          documentaries = results[11];
          romanceMovies = results[12];
          isLoading = false;

          // Pick a hero movie from Trending (falling back to Popular),
          // preferring an entry that actually has a backdrop image.
          final candidates = [...trending, ...popularMovies];
          heroMovie = candidates.firstWhere(
            (m) => m['backdrop_path'] != null,
            orElse: () => candidates.isNotEmpty ? candidates[Random().nextInt(candidates.length)] : null,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = AppBreakpoints.isDesktopOrTV(context);

    return AppScaffold(
      activeIndex: 0,
      constrainBody: false,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLoading)
              const _HeroSkeleton()
            else if (errorMessage != null)
              Container(
                height: 300,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white54, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      "Failed to load movies.\nPlease check your internet connection or API key.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _fetchMovies,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                      child: const Text("Retry", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              )
            else if (heroMovie != null)
              HeroBanner(movie: heroMovie),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: wide ? 0 : 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AppBreakpoints.maxContentWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
              if (!wide) ...[
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, SearchScreen.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search, color: Colors.white54),
                        SizedBox(width: 12),
                        Text("Search movies, TV series...", style: TextStyle(color: Colors.white54, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (continueWatching.isNotEmpty) ...[
                Text("Continue Watching", style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: continueWatching.length,
                    itemBuilder: (context, index) {
                      final entry = continueWatching[index];
                      return ContinueWatchingCard(
                        entry: entry,
                        onRemove: () async {
                          await WatchHistoryService.remove(
                            entry['id'],
                            season: entry['season'],
                            episode: entry['episode'],
                          );
                          if (mounted) {
                            setState(() {
                              continueWatching.removeAt(index);
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Moviesection(title: 'Trending Today', movies: trending, isLoading: isLoading),
              Moviesection(title: 'Now Playing', movies: nowPlayingMovies, isLoading: isLoading),
              Moviesection(title: 'Popular Movies', movies: popularMovies, isLoading: isLoading),
              Moviesection(title: 'Popular TV Shows', categoryType: 'TV Series', movies: tvSeries, isLoading: isLoading),
              Moviesection(title: 'Top Rated Movies', movies: topRatedMovies, isLoading: isLoading),
              Moviesection(title: 'Top Rated TV', movies: topRatedTV, isLoading: isLoading),
              Moviesection(title: 'Upcoming', movies: upcomingMovies, isLoading: isLoading),
              Moviesection(title: 'Action', movies: actionMovies, isLoading: isLoading),
              Moviesection(title: 'Sci-Fi & Fantasy', movies: sciFiMovies, isLoading: isLoading),
              Moviesection(title: 'Horror', movies: horrorMovies, isLoading: isLoading),
              Moviesection(title: 'Romance', movies: romanceMovies, isLoading: isLoading),
              Moviesection(title: 'Documentaries', movies: documentaries, isLoading: isLoading),
              Moviesection(title: 'Kids & Animation', movies: kidsMovies, isLoading: isLoading),
              if (myList.isNotEmpty) Moviesection(title: 'My List', movies: myList, isLoading: false),
              const SizedBox(height: 20),
                      ],
                    ),
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

/// Cinematic-shaped shimmer placeholder shown in the hero's spot while
/// the first batch of TMDB requests is still in flight — a full-width
/// backdrop block plus title/meta/button-shaped bars, rather than a
/// bare spinner.
class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    final bool wide = AppBreakpoints.isDesktopOrTV(context);
    return SizedBox(
      height: AppBreakpoints.heroHeight(context),
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Skeleton(borderRadius: 0),
          Positioned(
            left: wide ? 48 : 20,
            right: wide ? 48 : 20,
            bottom: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: wide ? 420 : 220, height: wide ? 44 : 28, borderRadius: 6),
                const SizedBox(height: 14),
                Skeleton(width: 160, height: 16, borderRadius: 4),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Skeleton(width: 120, height: 44, borderRadius: 6),
                    const SizedBox(width: 12),
                    const Skeleton(width: 140, height: 44, borderRadius: 6),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
