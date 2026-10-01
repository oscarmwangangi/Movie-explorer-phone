import 'package:flutter/material.dart';
import 'package:movie_explorer/appUI/home/category_results.dart';
import 'package:movie_explorer/appUI/services/tmdb_service.dart';
import 'package:movie_explorer/appUI/widget/hero_banner.dart';
import 'package:movie_explorer/appUI/widget/movieSection.dart';
import 'package:movie_explorer/appUI/shell/app_scaffold.dart';
import 'package:movie_explorer/theme/app_breakpoints.dart';
import 'package:movie_explorer/theme/app_colors.dart';

/// Dedicated TV Shows tab.
class TVShowsScreen extends StatefulWidget {
  static String id = 'tv_shows_screen';

  const TVShowsScreen({super.key});

  @override
  State<TVShowsScreen> createState() => _TVShowsScreenState();
}

class _TVShowsScreenState extends State<TVShowsScreen> {
  static const List<String> genres = ['TV Series', 'Top Rated TV'];

  dynamic featured;
  List popularTv = [];
  List topRatedTv = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final results = await Future.wait([
        TMDBService.getTVSeries(),
        TMDBService.getTopRatedTVSeries(),
      ]);
      if (!mounted) return;
      setState(() {
        popularTv = results[0];
        topRatedTv = results[1];
        featured = popularTv.isNotEmpty ? popularTv[0] : null;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString();
        });
      }
    }
  }

  void _openGenre(String genre) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryResultsScreen(title: genre, items: const []),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = AppBreakpoints.isDesktopOrTV(context);

    return AppScaffold(
      activeIndex: 2,
      constrainBody: false,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isLoading && featured == null)
                Container(
                  height: AppBreakpoints.heroHeight(context) * 0.7,
                  color: AppColors.surface,
                  child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                )
              else if (featured != null)
                HeroBanner(movie: featured),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AppBreakpoints.maxContentWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "TV Shows",
                              style: Theme.of(context).textTheme.displayLarge!.copyWith(fontSize: wide ? 32 : 24),
                            ),
                            IconButton(
                              icon: isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                    )
                                  : const Icon(Icons.refresh, color: Colors.white),
                              tooltip: "Refresh TV Shows",
                              onPressed: isLoading ? null : _load,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (errorMessage != null || (!isLoading && featured == null && popularTv.isEmpty))
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 48),
                                const SizedBox(height: 16),
                                const Text(
                                  "Failed to load TV shows.\nPlease check your connection and try again.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70, fontSize: 15),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _load,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text("Retry"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          SizedBox(
                            height: 40,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: genres.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (context, index) => ChoiceChip(
                                label: Text(genres[index]),
                                selected: false,
                                onSelected: (_) => _openGenre(genres[index]),
                                backgroundColor: AppColors.surface,
                                labelStyle: const TextStyle(color: Colors.white),
                                side: const BorderSide(color: AppColors.divider),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Moviesection(title: 'Popular TV Shows', categoryType: 'TV Series', movies: popularTv, isLoading: isLoading),
                          Moviesection(title: 'Top Rated TV', movies: topRatedTv, isLoading: isLoading),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
