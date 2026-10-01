import 'package:flutter/material.dart';
import 'package:movie_explorer/theme/app_colors.dart';
import 'package:movie_explorer/theme/app_breakpoints.dart';
import 'package:movie_explorer/appUI/services/tmdb_service.dart';
import 'package:movie_explorer/appUI/widget/moviecard.dart';
import 'package:movie_explorer/appUI/widget/skeleton.dart';
import 'package:movie_explorer/reusable/responsive.dart';

class CategoryResultsScreen extends StatefulWidget {
  final String title;
  final List items;

  /// Key used for TMDBService.getCategoryPage pagination. Defaults to
  /// [title] for backward compatibility with call sites that pass a
  /// title which already matches a valid category key.
  final String? categoryType;

  const CategoryResultsScreen({required this.title, required this.items, this.categoryType, super.key});

  @override
  State<CategoryResultsScreen> createState() => _CategoryResultsScreenState();
}

class _CategoryResultsScreenState extends State<CategoryResultsScreen> {
  List allItems = [];
  List displayedItems = [];
  int currentPage = 1;
  bool isLoadingMore = false;
  bool hasMore = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    allItems = List.from(widget.items);
    displayedItems = allItems;
    // If we're handed a pre-loaded first page (e.g. from a Home rail),
    // the next page to fetch is 2. If we start empty (e.g. a genre
    // filter chip that hasn't loaded anything yet), the next page is 1
    // so we don't skip the first page of results.
    currentPage = widget.items.isEmpty ? 0 : 1;
    _scrollController.addListener(_onScroll);
    // If the initial list is small, try to fetch the next page immediately
    if (allItems.length < 20) {
      _loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!isLoadingMore && hasMore && searchQuery.isEmpty) {
        _loadMore();
      }
    }
  }

  Future<void> _loadMore() async {
    setState(() => isLoadingMore = true);
    currentPage++;
    try {
      final newItems = await TMDBService.getCategoryPage(widget.categoryType ?? widget.title, currentPage);
      if (mounted) {
        setState(() {
          if (newItems.isEmpty) {
            hasMore = false;
          } else {
            allItems.addAll(newItems);
            _applyFilter(searchQuery);
          }
          isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingMore = false);
    }
  }

  void _applyFilter(String query) {
    searchQuery = query;
    setState(() {
      displayedItems = allItems.where((item) {
        final title = (item['title'] ?? item['name'] ?? '').toString().toLowerCase();
        return title.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: CenteredContent(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: _applyFilter,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search in ${widget.title}...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppColors.accent),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: displayedItems.length + (isLoadingMore ? 2 : 0),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: AppBreakpoints.gridCardExtent(context),
                  childAspectRatio: 2 / 3.8,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (context, index) {
                  if (index < displayedItems.length) {
                    return Moviecard(movie: displayedItems[index]);
                  } else {
                    return const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(height: 195, borderRadius: 12),
                        SizedBox(height: 8),
                        Skeleton(width: 100, height: 14),
                      ],
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
