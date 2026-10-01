import 'package:flutter/material.dart';
import 'package:movie_explorer/theme/app_colors.dart';
import 'package:movie_explorer/appUI/shell/app_scaffold.dart';
import 'package:movie_explorer/appUI/services/favorites_service.dart';
import 'package:movie_explorer/appUI/services/tmdb_service.dart';
import 'package:movie_explorer/appUI/widget/movieSection.dart';
import 'package:movie_explorer/appUI/home/trailer_player.dart';
import 'package:movie_explorer/appUI/home/movie_player.dart';
import 'package:movie_explorer/appUI/widget/skeleton.dart';
import 'package:movie_explorer/reusable/responsive.dart';

class MovieDetailsScreen extends StatefulWidget {
  final dynamic movie;
  final String? heroTag;

  const MovieDetailsScreen({required this.movie, this.heroTag, super.key});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  bool isFavorite = false;
  List similarMovies = [];
  bool isLoadingSimilar = true;
  Map<String, dynamic>? fullMovieDetails;
  bool isLoadingDetails = true;
  List videos = [];
  bool isLoadingVideos = true;
  Map<String, dynamic>? watchProviders;
  bool isLoadingProviders = true;

  // TV Specific
  List seasons = [];
  List episodes = [];
  int selectedSeason = 1;
  bool isLoadingEpisodes = false;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
    _fetchData();
  }

  Future<void> _fetchData() async {
    bool isTv = widget.movie['name'] != null || 
                widget.movie['first_air_date'] != null || 
                widget.movie['media_type'] == 'tv';
    try {
      final results = await Future.wait([
        TMDBService.getMovieDetails(widget.movie['id'], isTv: isTv),
        TMDBService.getSimilarContent(widget.movie['id'], isTv: isTv),
        TMDBService.getMovieVideos(widget.movie['id'], isTv: isTv),
        TMDBService.getWatchProviders(widget.movie['id'], isTv: isTv),
      ]);
      if (mounted) {
        setState(() {
          fullMovieDetails = results[0] as Map<String, dynamic>;
          isLoadingDetails = false;
          similarMovies = results[1] as List;
          isLoadingSimilar = false;
          videos = (results[2] as List).where((v) => v['site'] == 'YouTube').toList()
            ..sort((a, b) {
              int score(dynamic v) => v['type'] == 'Trailer' ? 0 : 1;
              return score(a).compareTo(score(b));
            });
          isLoadingVideos = false;
          watchProviders = results[3] as Map<String, dynamic>;
          isLoadingProviders = false;
        });

        if (isTv) {
          _fetchTVDetails();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingDetails = false;
          isLoadingSimilar = false;
          isLoadingVideos = false;
          isLoadingProviders = false;
        });
      }
    }
  }

  Future<void> _fetchTVDetails() async {
    try {
      final tvDetails = await TMDBService.getTVDetails(widget.movie['id']);
      if (mounted) {
        setState(() {
          seasons = tvDetails['seasons'] ?? [];
          if (seasons.isNotEmpty) {
            selectedSeason = seasons.first['season_number'];
            _fetchEpisodes(selectedSeason);
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching TV details: $e");
    }
  }

  Future<void> _fetchEpisodes(int seasonNumber) async {
    setState(() => isLoadingEpisodes = true);
    try {
      final episodeList = await TMDBService.getTVSeasonEpisodes(widget.movie['id'], seasonNumber);
      if (mounted) {
        setState(() {
          episodes = episodeList;
          isLoadingEpisodes = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingEpisodes = false);
    }
  }

  Future<void> _checkFavoriteStatus() async {
    bool status = await FavoritesService.isFavorite(widget.movie['id']);
    if (mounted) {
      setState(() {
        isFavorite = status;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (isFavorite) {
      await FavoritesService.removeFavorite(widget.movie['id']);
    } else {
      await FavoritesService.addFavorite(widget.movie);
    }
    if (mounted) {
      setState(() {
        isFavorite = !isFavorite;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFavorite ? "Added to Favorites" : "Removed from Favorites"),
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.surface,
        ),
      );
    }
  }

  Widget _buildTVSections() {
    if (seasons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text("Seasons", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: seasons.length,
            itemBuilder: (context, index) {
              final season = seasons[index];
              final bool isSelected = selectedSeason == season['season_number'];
              return GestureDetector(
                onTap: () {
                  setState(() => selectedSeason = season['season_number']);
                  _fetchEpisodes(selectedSeason);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    season['name'] ?? "Season ${season['season_number']}",
                    style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        const Text("Episodes", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        isLoadingEpisodes
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: episodes.length,
                itemBuilder: (context, index) {
                  final episode = episodes[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: episode['still_path'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                'https://image.tmdb.org/t/p/w200${episode['still_path']}',
                                width: 80,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(width: 80, height: 60, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.movie, color: Colors.white24)),
                      title: Text("E${episode['episode_number']}: ${episode['name']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(episode['air_date'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_circle_fill, color: AppColors.accent, size: 32),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MoviePlayerScreen(
                                tmdbId: widget.movie['id'],
                                title: "${widget.movie['name'] ?? 'TV Show'} - S$selectedSeason E${episode['episode_number']}",
                                isTv: true,
                                season: selectedSeason,
                                episode: episode['episode_number'],
                                posterPath: episode['still_path'] ?? widget.movie['poster_path'],
                                backdropPath: widget.movie['backdrop_path'],
                                voteAverage: widget.movie['vote_average'],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildWatchProvidersSection() {
    if (isLoadingProviders) return const Skeleton(width: double.infinity, height: 60);
    
    final usData = watchProviders?['US'];
    if (usData == null || usData['flatrate'] == null) {
      return const SizedBox.shrink();
    }

    final providers = usData['flatrate'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Available on",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final provider = providers[index];
              final logoUrl = 'https://image.tmdb.org/t/p/original${provider['logo_path']}';
              return Container(
                margin: const EdgeInsets.only(right: 12),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: NetworkImage(logoUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrailerSection() {
    if (isLoadingVideos) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 80, height: 24),
            SizedBox(height: 12),
            Skeleton(width: double.infinity, height: 200, borderRadius: 12),
          ],
        ),
      );
    }

    if (videos.isEmpty) {
      return const SizedBox.shrink();
    }

    final trailer = videos.first;
    final String youtubeKey = trailer['key'];
    final String thumbnailUrl = 'https://img.youtube.com/vi/$youtubeKey/hqdefault.jpg';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          "Trailer",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TrailerPlayerScreen(
                  youtubeKey: youtubeKey,
                  title: widget.movie['title'] ?? widget.movie['name'] ?? 'Trailer',
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: AppColors.surface),
                  ),
                  Container(color: Colors.black.withOpacity(0.3)),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    bool isTv = movie['name'] != null || movie['first_air_date'] != null || movie['media_type'] == 'tv';
    String title = movie['title'] ?? movie['name'] ?? 'Unknown Title';
    String overview = movie['overview'] ?? 'No description available.';
    String year = (movie['release_date'] ?? movie['first_air_date'])?.toString().split('-')[0] ?? 'N/A';
    double rating = (movie['vote_average'] as num?)?.toDouble() ?? 0.0;
    String? posterPath = movie['poster_path'];
    String? backdropPath = movie['backdrop_path'];
    
    String posterUrl = posterPath != null
        ? 'https://image.tmdb.org/t/p/w500$posterPath'
        : 'https://image.tmdb.org/t/p/w500/9SSEUrSqhljBMzRe4aBTh17rUaC.jpg';
        
    String backdropUrl = backdropPath != null
        ? 'https://image.tmdb.org/t/p/w1280$backdropPath'
        : posterUrl;

    return AppScaffold(
      activeIndex: 0,
      constrainBody: false,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 450,
            pinned: true,
            backgroundColor: const Color(0xFF121212),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black45,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    backdropUrl,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Color(0xFF121212),
                        ],
                        stops: [0, 0.5, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [Shadow(color: Colors.black, blurRadius: 10, offset: Offset(2, 2))],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(year, style: const TextStyle(color: Colors.white70, fontSize: 18)),
                            const SizedBox(width: 16),
                            const Icon(Icons.star, color: Colors.amber, size: 22),
                            const SizedBox(width: 4),
                            Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: CenteredContent(
              child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isTv)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MoviePlayerScreen(
                                    tmdbId: movie['id'],
                                    title: title,
                                    isTv: false,
                                    posterPath: movie['poster_path'],
                                    backdropPath: movie['backdrop_path'],
                                    voteAverage: movie['vote_average'],
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              minimumSize: const Size(0, 56),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              "Watch Now",
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: IconButton(
                            onPressed: _toggleFavorite,
                            icon: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? Colors.red : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    "Na revue",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    overview,
                    style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Genres",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  if (isLoadingDetails)
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Skeleton(width: 80, height: 35),
                        Skeleton(width: 100, height: 35),
                        Skeleton(width: 70, height: 35),
                      ],
                    )
                  else if (fullMovieDetails != null && fullMovieDetails!['genres'] != null)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (fullMovieDetails!['genres'] as List).map((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            genre['name'],
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                    ),
                  
                  if (isTv) _buildTVSections(),
                  _buildWatchProvidersSection(),
                  _buildTrailerSection(),
                  
                  const SizedBox(height: 32),
                  Moviesection(
                    title: 'Related Movies',
                    movies: similarMovies,
                    isLoading: isLoadingSimilar,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
