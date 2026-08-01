import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game.dart';
import 'game_library_provider.dart';

/// Holds the current search query string.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Indexed search results — filtered list of games matching the query.
/// Priority: IGDB name (metadata.igdbId exists → use metadata summary/genres)
/// > game.name (folder name) > genres/developer/publisher.
final searchResultsProvider = Provider<AsyncValue<List<Game>>>((ref) {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final gamesAsync = ref.watch(gameLibraryProvider);

  if (query.isEmpty) return gamesAsync;

  return gamesAsync.whenData((games) {
    return games.where((game) {
      return _matchesQuery(game, query);
    }).toList()
      ..sort((a, b) => _relevanceScore(b, query).compareTo(_relevanceScore(a, query)));
  });
});

bool _matchesQuery(Game game, String query) {
  // Game name (folder name) — primary match
  if (game.name.toLowerCase().contains(query)) return true;

  // Metadata fields
  final meta = game.metadata;
  if (meta == null) return false;

  // IGDB name / summary
  if (meta.summary != null && meta.summary!.toLowerCase().contains(query)) return true;

  // Genres
  if (meta.genres.any((g) => g.toLowerCase().contains(query))) return true;

  // Developer / publisher
  if (meta.developer != null && meta.developer!.toLowerCase().contains(query)) return true;
  if (meta.publisher != null && meta.publisher!.toLowerCase().contains(query)) return true;

  // Release date
  if (meta.releaseDate != null && meta.releaseDate!.toLowerCase().contains(query)) return true;

  return false;
}

/// Scores how relevant a game is to the query. Higher = more relevant.
int _relevanceScore(Game game, String query) {
  int score = 0;
  final nameLower = game.name.toLowerCase();

  // Exact match on name
  if (nameLower == query) return 100;

  // Name starts with query
  if (nameLower.startsWith(query)) score += 50;

  // Name contains query
  if (nameLower.contains(query)) score += 30;

  // Genre match
  final meta = game.metadata;
  if (meta != null) {
    if (meta.genres.any((g) => g.toLowerCase().contains(query))) score += 10;
    if (meta.developer?.toLowerCase().contains(query) == true) score += 8;
    if (meta.publisher?.toLowerCase().contains(query) == true) score += 8;
    if (meta.summary?.toLowerCase().contains(query) == true) score += 5;
  }

  return score;
}
