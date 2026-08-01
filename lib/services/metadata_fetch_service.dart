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
        final sgResults = await steamGridDb!.search(game.name);
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
        final results = await steamGridDb!.search(game.name);
        if (results.isNotEmpty) {
          coverUrl = await steamGridDb!.getCoverUrl(results.first.id);
        }
      } catch (e) {
        print('[MetadataFetch] SteamGridDB error for ${game.name}: $e');
      }
    }

    if (coverUrl == null && igdb != null && igdb!.isAuthenticated) {
      try {
        final results = await igdb!.search(game.name);
        if (results.isNotEmpty) {
          coverUrl = results.first.thumbnailUrl ??
              await igdb!.getCoverUrl(results.first.id);
        }
      } catch (e) {
        print('[MetadataFetch] IGDB error for ${game.name}: $e');
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
