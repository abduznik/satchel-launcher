import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../models/game.dart';
import '../models/api_search_result.dart';
import 'steamgriddb_api.dart';
import 'igdb_api.dart';

class MetadataFetchService {
  final SteamGridDbApi? steamGridDb;
  final IgdbApi? igdb;
  final Dio _dio;

  MetadataFetchService({this.steamGridDb, this.igdb, Dio? dio})
      : _dio = dio ?? Dio();

  // ---------------------------------------------------------------------------
  // Search — returns a list for the picker UI
  // ---------------------------------------------------------------------------
  Future<List<ApiSearchResult>> searchCandidates(String query) async {
    final results = <ApiSearchResult>[];

    // Try IGDB first (has full metadata)
    if (igdb != null && igdb!.isAuthenticated) {
      try {
        final igdbResults = await igdb!.search(query);
        results.addAll(igdbResults);
      } catch (e) {
        print('[MetadataFetch] IGDB search error: $e');
      }
    }

    // If no IGDB results, try SteamGridDB (cover art only)
    if (results.isEmpty && steamGridDb != null) {
      try {
        final sgResults = await steamGridDb!.search(query);
        results.addAll(sgResults);
      } catch (e) {
        print('[MetadataFetch] SteamGridDB search error: $e');
      }
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // Name confidence — how confident we are that a search result is this game.
  // Used by the background auto-fetch so it never applies a wrong match
  // (e.g. "Dark" (2013) must not be matched to "Thief") and never overwrites
  // manually-curated metadata.
  // ---------------------------------------------------------------------------

  /// 0.0–1.0 similarity between the game folder name and a candidate title.
  /// 1.0 = exact match, ≥0.9 = one contains the other, else Levenshtein +
  /// word-overlap blended.
  static double nameConfidence(String gameName, String candidateName) {
    final a = gameName.toLowerCase().trim();
    final b = candidateName.toLowerCase().trim();
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a == b) return 1.0;
    if (a.contains(b) || b.contains(a)) return 0.9;

    final distance = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return 0.0;
    final similarity = 1.0 - (distance / maxLen);

    final aWords = a.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    final bWords = b.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    final denom = aWords.length > bWords.length ? aWords.length : bWords.length;
    final wordBonus = denom == 0 ? 0.0 : aWords.intersection(bWords).length / denom;

    return (similarity * 0.7 + wordBonus * 0.3).clamp(0.0, 1.0);
  }

  /// Minimum confidence for the auto-fetch to apply a candidate automatically.
  static const double autoApplyThreshold = 0.75;

  static int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final dp = List.generate(a.length + 1, (i) => List.generate(b.length + 1, (j) => 0));
    for (var i = 0; i <= a.length; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return dp[a.length][b.length];
  }

  /// Fetch full metadata + images for a selected result and save to disk.
  /// If [clearOld] is true, deletes existing cover/banner/screenshots first.
  Future<FetchedGameData> fetchFull(
    Game game,
    ApiSearchResult selected, {
    bool clearOld = false,
  }) async {
    String? coverPath;
    String? bannerPath;
    GameMetadata? metadata;
    List<String> screenshotPaths = [];

    final indieDir = Directory(p.join(game.folderPath, '.indie'));
    if (!await indieDir.exists()) await indieDir.create(recursive: true);

    // Clear old assets if requested (for re-fetch / manual override)
    if (clearOld) {
      print('[MetadataFetch] Clearing old assets for ${game.name}');
      final oldCover = File(p.join(indieDir.path, 'cover.jpg'));
      final oldBanner = File(p.join(indieDir.path, 'banner.jpg'));
      final oldSS = Directory(p.join(indieDir.path, 'screenshots'));
      if (await oldCover.exists()) await oldCover.delete();
      if (await oldBanner.exists()) await oldBanner.delete();
      if (await oldSS.exists()) await oldSS.delete(recursive: true);
    }

    if (selected.source == 'igdb' && igdb != null && igdb!.isAuthenticated) {
      final details = await igdb!.getFullDetails(selected.id);
      if (details != null) {
        metadata = details.metadata;

        // Cover
        if (details.coverUrl != null) {
          coverPath = await _downloadImage(
            details.coverUrl!,
            p.join(indieDir.path, 'cover.jpg'),
          );
        }

        // Banner / hero
        if (details.bannerUrl != null) {
          bannerPath = await _downloadImage(
            details.bannerUrl!,
            p.join(indieDir.path, 'banner.jpg'),
          );
        }

        // Screenshots — download up to 6
        final ssDir = Directory(p.join(indieDir.path, 'screenshots'));
        if (!await ssDir.exists()) await ssDir.create();
        int i = 0;
        for (final url in details.screenshotUrls.take(6)) {
          final path = await _downloadImage(url, p.join(ssDir.path, 'ss_$i.jpg'));
          if (path != null) {
            screenshotPaths.add(path);
            i++;
          }
        }

        // Attach screenshot paths to metadata
        metadata = metadata.copyWith(screenshots: screenshotPaths);
      }
    }

    // If cover still null try SteamGridDB
    if (coverPath == null && steamGridDb != null) {
      try {
        final sgResults = await steamGridDb!.search(game.displayName);
        if (sgResults.isNotEmpty) {
          final url = await steamGridDb!.getCoverUrl(sgResults.first.id);
          if (url != null) {
            coverPath = await _downloadImage(
              url,
              p.join(indieDir.path, 'cover.jpg'),
            );
          }
        }
      } catch (e) {
        print('[MetadataFetch] SteamGridDB fallback error: $e');
      }
    }

    return FetchedGameData(
      coverPath: coverPath,
      bannerPath: bannerPath,
      metadata: metadata,
    );
  }

  // ---------------------------------------------------------------------------
  // Quick cover-only fetch (used by background scanner)
  // ---------------------------------------------------------------------------
  Future<String?> fetchCover(Game game) async {
    String? coverUrl;

    if (steamGridDb != null) {
      try {
        final results = await steamGridDb!.search(game.displayName);
        if (results.isNotEmpty) {
          coverUrl = await steamGridDb!.getCoverUrl(results.first.id);
        }
      } catch (e) {
        print('[MetadataFetch] SteamGridDB error for ${game.displayName}: $e');
      }
    }

    if (coverUrl == null && igdb != null && igdb!.isAuthenticated) {
      try {
        final results = await igdb!.search(game.displayName);
        if (results.isNotEmpty) {
          coverUrl = results.first.thumbnailUrl ??
              await igdb!.getCoverUrl(results.first.id);
        }
      } catch (e) {
        print('[MetadataFetch] IGDB error for ${game.displayName}: $e');
      }
    }

    if (coverUrl == null || coverUrl.isEmpty) return null;

    final indieDir = Directory(p.join(game.folderPath, '.indie'));
    if (!await indieDir.exists()) await indieDir.create(recursive: true);
    return _downloadImage(coverUrl, p.join(indieDir.path, 'cover.jpg'));
  }

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------
  Future<String?> _downloadImage(String url, String destPath) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data != null && response.data!.isNotEmpty) {
        await File(destPath).writeAsBytes(response.data!);
        return destPath;
      }
    } catch (e) {
      print('[MetadataFetch] Download error $url: $e');
    }
    return null;
  }
}

class FetchedGameData {
  final String? coverPath;
  final String? bannerPath;
  final GameMetadata? metadata;

  FetchedGameData({this.coverPath, this.bannerPath, this.metadata});
}
