import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks recently-opened titles for the Home screen's "Continue
/// Watching" rail, persisted locally with SharedPreferences.
///
/// Important limitation: movie/TV playback happens inside a third-party
/// embedded player (vidsrc) that the app doesn't control, so there is no
/// way to read back actual playback position/percentage from it. This
/// service therefore tracks *recently opened* titles, not verified
/// watch progress. `progress` is a simple heuristic (100% once opened)
/// rather than a real measurement — the UI should be honest about that.
class WatchHistoryService {
  static const String _key = 'watch_history';
  static const int _maxEntries = 20;

  /// Records that [movie] (a raw TMDB map) was opened for playback.
  /// If it's a TV episode, pass [isTv], [season], and [episode] so the
  /// Continue Watching card can show "S1 E3" and resume the same spot.
  static Future<void> recordWatch(
    dynamic movie, {
    bool isTv = false,
    int? season,
    int? episode,
  }) async {
    if (movie == null || movie['id'] == null) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_key) ?? [];

    final entry = {
      'id': movie['id'],
      'title': movie['title'] ?? movie['name'],
      'poster_path': movie['poster_path'],
      'backdrop_path': movie['backdrop_path'],
      'vote_average': movie['vote_average'],
      'is_tv': isTv,
      'season': season,
      'episode': episode,
      'last_watched': DateTime.now().millisecondsSinceEpoch,
    };

    // Remove any existing entry for this exact title (and episode, for TV)
    // so re-opening moves it back to the front instead of duplicating it.
    history.removeWhere((item) {
      final decoded = jsonDecode(item);
      if (decoded['id'] != movie['id']) return false;
      if (isTv) {
        return decoded['season'] == season && decoded['episode'] == episode;
      }
      return true;
    });

    history.insert(0, jsonEncode(entry));
    if (history.length > _maxEntries) {
      history = history.sublist(0, _maxEntries);
    }

    await prefs.setStringList(_key, history);
  }

  /// Returns recently-opened titles, most recent first.
  static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_key) ?? [];
    return history
        .map((item) => Map<String, dynamic>.from(jsonDecode(item)))
        .toList();
  }

  static Future<void> remove(int id, {int? season, int? episode}) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_key) ?? [];
    history.removeWhere((item) {
      final decoded = jsonDecode(item);
      if (decoded['id'] != id) return false;
      if (season != null || episode != null) {
        return decoded['season'] == season && decoded['episode'] == episode;
      }
      return true;
    });
    await prefs.setStringList(_key, history);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
