import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// A service class to handle communication with The Movie Database (TMDB) API.
class TMDBService {
  /// The API key required for authenticating with TMDB, now loaded from .env.
  static String get apiKey => dotenv.env['TMDB_API_KEY'] ?? "";

  static Future<http.Response> _get(Uri url) {
    return http.get(url).timeout(const Duration(seconds: 10));
  }

  /// Searches for movies on TMDB based on the provided [query].
  /// Returns a list of movie objects as [List<dynamic>].
  /// Throws an [Exception] if the API call fails.
  static Future<List> searchMovies(String query) async {
    // Construct the search URL with the API key and query.
    final url = Uri.parse(
        "https://api.themoviedb.org/3/search/movie?api_key=$apiKey&query=$query");

    // Perform an asynchronous HTTP GET request.
    final response = await _get(url);

    if (response.statusCode == 200) {
      // Decode the JSON response body.
      final data = json.decode(response.body);
      // Return the 'results' portion of the response.
      return data["results"];
    } else {
      // Handle unsuccessful response codes.
      print("TMDB API Error: ${response.statusCode} - ${response.body}");
      throw Exception("Failed to load movies from TMDB. Status: ${response.statusCode}");
    }
  }

  /// Fetches popular movies from TMDB.
  static Future<List> getPopularMovies() async {
    final url = Uri.parse(
        "https://api.themoviedb.org/3/discover/movie?api_key=$apiKey&include_adult=false&include_video=false&language=en-US&page=1&sort_by=popularity.desc");

    final response = await _get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["results"];
    } else {
      throw Exception("Failed to load popular movies from TMDB.");
    }
  }

  /// Fetches top rated movies from TMDB.
  static Future<List> getTopRatedMovies() async {
    final url = Uri.parse(
        "https://api.themoviedb.org/3/discover/movie?api_key=$apiKey&include_adult=false&include_video=false&language=en-US&page=1&sort_by=vote_average.desc&without_genres=99,10755&vote_count.gte=200");

    final response = await _get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["results"];
    } else {
      throw Exception("Failed to load top rated movies from TMDB.");
    }
  }

  /// Fetches upcoming movies from TMDB.
  static Future<List> getUpcomingMovies() async {
    final url = Uri.parse(
        "https://api.themoviedb.org/3/movie/upcoming?api_key=$apiKey&language=en-US&page=1");

    final response = await _get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["results"];
    } else {
      throw Exception("Failed to load upcoming movies from TMDB.");
    }
  }

  /// Fetches movies currently playing in theaters from TMDB.
  /// Used to power the "Now Playing" row on the Home screen.
  static Future<List> getNowPlayingMovies() async {
    final url = Uri.parse(
        "https://api.themoviedb.org/3/movie/now_playing?api_key=$apiKey&language=en-US&page=1");

    final response = await _get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["results"];
    } else {
      throw Exception("Failed to load now playing movies from TMDB.");
    }
  }

  /// Fetches movie videos (trailers, teasers, etc.) for a specific movie ID.
  static Future<List> getMovieVideos(int movieId, {bool isTv = false}) async {
    final type = isTv ? 'tv' : 'movie';
    final url = Uri.parse(
        "https://api.themoviedb.org/3/$type/$movieId/videos?api_key=$apiKey&language=en-US");

    final response = await _get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["results"];
    } else {
      throw Exception("Failed to load videos from TMDB.");
    }
  }

  /// Fetches similar movies/TV for a specific ID.
  static Future<List> getSimilarContent(int id, {bool isTv = false}) async {
    final type = isTv ? 'tv' : 'movie';
    final url = Uri.parse(
        "https://api.themoviedb.org/3/$type/$id/similar?api_key=$apiKey&language=en-US&page=1");
    final response = await _get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["results"];
    } else {
      throw Exception("Failed to load similar content from TMDB.");
    }
  }

  /// Fetches full details for a specific movie.
  static Future<Map<String, dynamic>> getMovieDetails(int movieId, {bool isTv = false}) async {
    final type = isTv ? 'tv' : 'movie';
    final url = Uri.parse(
        "https://api.themoviedb.org/3/$type/$movieId?api_key=$apiKey&language=en-US");
    final response = await _get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load details from TMDB.");
    }
  }

  /// Fetches popular TV series.
  static Future<List> getTVSeries() async {
    final url = Uri.parse(
        "https://api.themoviedb.org/3/tv/popular?api_key=$apiKey&language=en-US&page=1");
    final response = await _get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["results"];
    } else {
      throw Exception("Failed to load TV series from TMDB.");
    }
  }

  /// Fetches Horror movies.
  static Future<List> getHorrorMovies() async {
    final url = Uri.parse(
        "https://api.themoviedb.org/3/discover/movie?api_key=$apiKey&with_genres=27");
    final response = await _get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["results"];
    } else {
      throw Exception("Failed to load horror movies from TMDB.");
    }
  }

  /// Fetches Animation/Kids movies.
  static Future<List> getKidsMovies() async {
    final url = Uri.parse(
        "https://api.themoviedb.org/3/discover/movie?api_key=$apiKey&with_genres=16,10751");
    final response = await _get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["results"];
    } else {
      throw Exception("Failed to load kids movies from TMDB.");
    }
  }

  /// Fetches Trending content.
  static Future<List> getTrending() async {
    final url = Uri.parse(
        "https://api.themoviedb.org/3/trending/all/day?api_key=$apiKey");
    final response = await _get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["results"];
    } else {
      throw Exception("Failed to load trending content from TMDB.");
    }
  }

  /// Fetches Action movies.
  static Future<List> getActionMovies() async {
    final url = Uri.parse(
        "https://api.themoviedb.org/3/discover/movie?api_key=$apiKey&with_genres=28");
    final response = await _get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["results"];
    } else {
      throw Exception("Failed to load action movies from TMDB.");
    }
  }

  /// Fetches Sci-Fi & Fantasy movies.
  static Future<List> getSciFiFantasyMovies() async {
    final url = Uri.parse(
        "https://api.themoviedb.org/3/discover/movie?api_key=$apiKey&with_genres=878,14");
    final response = await _get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["results"];
    } else {
      throw Exception("Failed to load Sci-Fi & Fantasy movies from TMDB.");
    }
  }

  /// Fetches Documentaries.
  static Future<List> getDocumentaries() async {
    final url = Uri.parse(
        "https://api.themoviedb.org/3/discover/movie?api_key=$apiKey&with_genres=99");
    final response = await _get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["results"];
    } else {
      throw Exception("Failed to load documentaries from TMDB.");
    }
  }

  /// Fetches Romance movies.
  static Future<List> getRomanceMovies() async {
    final url = Uri.parse(
        "https://api.themoviedb.org/3/discover/movie?api_key=$apiKey&with_genres=10749");
    final response = await _get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["results"];
    } else {
      throw Exception("Failed to load romance movies from TMDB.");
    }
  }

  /// Fetches Top Rated TV Series.
  static Future<List> getTopRatedTVSeries() async {
    final url = Uri.parse(
        "https://api.themoviedb.org/3/tv/top_rated?api_key=$apiKey&language=en-US&page=1");
    final response = await _get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["results"];
    } else {
      throw Exception("Failed to load top rated TV series from TMDB.");
    }
  }

  /// Fetches where to watch the movie/TV (Streaming, Rent, Buy).
  static Future<Map<String, dynamic>> getWatchProviders(int id, {bool isTv = false}) async {
    final type = isTv ? 'tv' : 'movie';
    final url = Uri.parse(
        "https://api.themoviedb.org/3/$type/$id/watch/providers?api_key=$apiKey");
    final response = await _get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["results"] ?? {};
    }
    return {};
  }

  /// Fetches TV series details including seasons.
  static Future<Map<String, dynamic>> getTVDetails(int tvId) async {
    final url = Uri.parse(
        "https://api.themoviedb.org/3/tv/$tvId?api_key=$apiKey&language=en-US");
    final response = await _get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load TV details from TMDB.");
    }
  }

  /// Fetches episodes for a specific TV season.
  static Future<List> getTVSeasonEpisodes(int tvId, int seasonNumber) async {
    final url = Uri.parse(
        "https://api.themoviedb.org/3/tv/$tvId/season/$seasonNumber?api_key=$apiKey&language=en-US");
    final response = await _get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data["episodes"];
    } else {
      throw Exception("Failed to load TV season episodes from TMDB.");
    }
  }

  /// Searches for movies, TV shows, and more using the Multi Search endpoint.
  static Future<List> multiSearch(String query) async {
    final url = Uri.parse(
        "https://api.themoviedb.org/3/search/multi?api_key=$apiKey&query=$query&include_adult=false&language=en-US&page=1");

    final response = await _get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Filter out 'person' results if only movies and TV are desired.
      return (data["results"] as List)
          .where((item) => item["media_type"] == "movie" || item["media_type"] == "tv")
          .toList();
    } else {
      throw Exception("Failed to perform multi search.");
    }
  }

  /// Fetches paginated movies/TV for a category.
  static Future<List> getCategoryPage(String categoryType, int page) async {
    String endpoint;
    switch (categoryType.toLowerCase()) {
      case 'trending today':
        endpoint = "trending/all/day";
        break;
      case 'now playing':
        endpoint = "movie/now_playing";
        break;
      case 'popular movies':
        endpoint = "movie/popular";
        break;
      case 'top rated movies':
        endpoint = "movie/top_rated";
        break;
      case 'upcoming':
        endpoint = "movie/upcoming";
        break;
      case 'tv series':
        endpoint = "tv/popular";
        break;
      case 'top rated tv':
        endpoint = "tv/top_rated";
        break;
      case 'action':
        endpoint = "discover/movie?with_genres=28";
        break;
      case 'sci-fi & fantasy':
        endpoint = "discover/movie?with_genres=878,14";
        break;
      case 'horror':
        endpoint = "discover/movie?with_genres=27";
        break;
      case 'kids & animation':
        endpoint = "discover/movie?with_genres=16,10751";
        break;
      case 'documentaries':
        endpoint = "discover/movie?with_genres=99";
        break;
      case 'romance':
        endpoint = "discover/movie?with_genres=10749";
        break;
      default:
        return [];
    }

    final separator = endpoint.contains('?') ? '&' : '?';
    final url = Uri.parse(
        "https://api.themoviedb.org/3/$endpoint${separator}api_key=$apiKey&page=$page");

    final response = await _get(url);
    if (response.statusCode == 200) {
      return json.decode(response.body)["results"];
    }
    return [];
  }
}
