import 'package:flutter/material.dart';
import 'package:movie_explorer/theme/app_colors.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController searchController;
  final Function(String) onSearch;

  const SearchBarWidget({
    super.key,
    required this.searchController,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface, // Dark gray fill
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: searchController,
        onChanged: onSearch,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search, color: Color(0xFFA0A0A0)),
          hintText: "Search movies",
          hintStyle: TextStyle(color: Color(0xFFA0A0A0)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}
