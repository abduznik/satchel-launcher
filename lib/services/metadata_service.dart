import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../models/game.dart';
import '../models/api_config.dart';
import '../models/api_search_result.dart';
import 'steamgriddb_api.dart';
import 'igdb_api.dart';
import 'screenscraper_api.dart' as ss;

class MetadataService {
  final SteamGridDbApi _steamGridDb;
  final IgdbApi _igdb;
  final ss.ScreenScraperApi _screenScraper;
  final ApiConfig _config;
  final Dio _dio;

  MetadataService({
    required SteamGridDbApi steamGridDb,
    required IgdbApi igdb,
    required ss.ScreenScraperApi screenScraper,
    required ApiConfig config,
    Dio? dio,
  })  : _steamGridDb = steamGridDb,
        _igdb = igdb,
        _screenScraper = screenScraper,
        _config = config,
        _dio = dio ?? Dio();

  Future<List<ApiSearchResult>> searchAll(String query) async {
    final results = <ApiSearchResult>[];

    if (_config.steamGridDbEnabled) {
      final sgdResults = await _steamGridDb.search(query);
      results.addAll(sgdResults);
    }

    if (_config.igdbEnabled) {
      final igdbResults = await _igdb.search(query);
      results.addAll(igdbResults);
    }

    if (_config.screenScraperEnabled) {
      final ssResults = await _screenScraper.search(query);
      results.addAll(ssResults);
    }

    return results;
  }

  Future<String?> getCover(String gameId, String source) async {
    switch (source) {
      case 'steamgriddb':
        return await _steamGridDb.getCoverUrl(gameId);
      case 'igdb':
        // IGDB doesn't provide direct cover URLs in search
        return null;
      case 'screenscraper':
        return await _screenScraper.getCoverUrl(gameId);
      default:
        return null;
    }
  }

  Future<GameMetadata?> getMetadata(String gameId, String source) async {
    switch (source) {
      case 'igdb':
        return await _igdb.getGameDetails(gameId);
      default:
        return null;
    }
  }

  Future<void> saveMetadata(Game game, GameMetadata metadata, String? coverPath) async {
    final indieDir = Directory(p.join(game.folderPath, '.indie'));
    if (!await indieDir.exists()) {
      await indieDir.create(recursive: true);
    }

    // Save metadata JSON
    final metaFile = File(p.join(indieDir.path, 'meta.json'));
    final json = metadata.toJson();
    if (coverPath != null) {
      json['coverPath'] = coverPath;
    }
    await metaFile.writeAsString(jsonEncode(json));

    // Download and save cover if URL provided
    if (coverPath != null && coverPath.startsWith('http')) {
      await _downloadCover(coverPath, p.join(indieDir.path, 'cover.jpg'));
    }
  }

  Future<void> _downloadCover(String url, String savePath) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final file = File(savePath);
      await file.writeAsBytes(response.data);
    } catch (_) {}
  }
}
