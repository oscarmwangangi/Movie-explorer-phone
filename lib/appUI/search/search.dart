import 'package:flutter/material.dart';
import 'package:movie_explorer/appUI/shell/app_scaffold.dart';
import 'package:movie_explorer/appUI/widget/searchExpandedWidget.dart';
import 'package:movie_explorer/appUI/widget/searchBar.dart';
import 'package:movie_explorer/appUI/services/tmdb_service.dart';
import 'package:movie_explorer/theme/app_colors.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  static String id = "search_screen";

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();
  List allResults = [];
  List movies = [];
  bool isLoading = false;
  int _tab = 0; // 0 = All, 1 = Movies, 2 = TV

  void onSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        allResults = [];
        movies = [];
      });
      return;
    }
    setState(() => isLoading = true);
    try {
      final results = await TMDBService.multiSearch(query);
      if (mounted) {
        setState(() {
          allResults = results;
          isLoading = false;
        });
        _applyTabFilter();
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyTabFilter() {
    setState(() {
      switch (_tab) {
        case 1:
          movies = allResults.where((m) => m['media_type'] == 'movie').toList();
          break;
        case 2:
          movies = allResults.where((m) => m['media_type'] == 'tv').toList();
          break;
        default:
          movies = allResults;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      activeIndex: 4,
      appBar: AppBar(
        title: const Text("Search"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            SearchBarWidget(searchController: searchController, onSearch: onSearch),
            if (allResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  _SearchTab(label: "All", selected: _tab == 0, onTap: () => setState(() { _tab = 0; _applyTabFilter(); })),
                  const SizedBox(width: 8),
                  _SearchTab(label: "Movies", selected: _tab == 1, onTap: () => setState(() { _tab = 1; _applyTabFilter(); })),
                  const SizedBox(width: 8),
                  _SearchTab(label: "TV Shows", selected: _tab == 2, onTap: () => setState(() { _tab = 2; _applyTabFilter(); })),
                ],
              ),
            ],
            const SizedBox(height: 12),
            searchExpandedWidget(movies: movies, isLoading: isLoading),
          ],
        ),
      ),
    );
  }
}

class _SearchTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SearchTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
