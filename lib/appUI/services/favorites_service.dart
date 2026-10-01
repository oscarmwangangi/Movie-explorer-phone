import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A service to handle persistent storage of favorite movies using SharedPreferences.
class FavoritesService {
  static const String _key = 'favorite_movies';

  /// Adds a movie to the favorites list.
  static Future<void> addFavorite(dynamic movie) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList(_key) ?? [];
    
    // Check if movie already exists to avoid duplicates
    String movieJson = jsonEncode(movie);
    bool exists = favorites.any((item) {
      Map decoded = jsonDecode(item);
      return decoded['id'] == movie['id'];
    });

    if (!exists) {
      favorites.add(movieJson);
      await prefs.setStringList(_key, favorites);
    }
  }

  /// Removes a movie from the favorites list.
  static Future<void> removeFavorite(int movieId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList(_key) ?? [];
    
    favorites.removeWhere((item) {
      Map decoded = jsonDecode(item);
      return decoded['id'] == movieId;
    });
    
    await prefs.setStringList(_key, favorites);
  }

  /// Returns all favorite movies.
  static Future<List> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList(_key) ?? [];
    return favorites.map((item) => jsonDecode(item)).toList();
  }

  /// Checks if a movie is in the favorites list.
  static Future<bool> isFavorite(int movieId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList(_key) ?? [];
    return favorites.any((item) {
      Map decoded = jsonDecode(item);
      return decoded['id'] == movieId;
    });
  }
}
