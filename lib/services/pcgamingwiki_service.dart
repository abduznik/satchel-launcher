import 'dart:io';
import 'package:dio/dio.dart';

class PcgamingwikiService {
  static const _baseUrl = 'https://www.pcgamingwiki.com';
  final Dio _dio;

  PcgamingwikiService({Dio? dio}) : _dio = dio ?? Dio();

  /// Search for a game on PCGamingWiki
  Future<List<PcgamingwikiResult>> search(String query) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/w/api.php',
        queryParameters: {
          'action': 'opensearch',
          'search': query,
          'limit': 10,
          'namespace': 0,
          'format': 'json',
        },
      );

      final data = response.data;
      if (data is List && data.length >= 2) {
        final names = data[1] as List;
        final urls = data[3] as List;

        return List.generate(names.length, (i) {
          return PcgamingwikiResult(
            name: names[i].toString(),
            url: urls[i].toString(),
          );
        });
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Fetch save game locations from a PCGamingWiki game page
  Future<SaveGameInfo?> getSaveLocations(String gameUrl) async {
    try {
      final response = await _dio.get(gameUrl);
      final html = response.data.toString();

      return _parseSaveLocations(html);
    } catch (_) {
      return null;
    }
  }

  SaveGameInfo? _parseSaveLocations(String html) {
    // Find the Save game data section
    final saveSection = _extractSection(html, 'Save game data');
    if (saveSection == null) return null;

    final locations = <SaveLocation>[];

    // Parse Windows save locations
    final windowsPaths = _extractPaths(saveSection, 'Windows');
    for (final path in windowsPaths) {
      locations.add(SaveLocation(
        platform: 'Windows',
        path: path,
        type: _determineLocationType(path),
      ));
    }

    // Parse cloud sync info
    final cloudSync = html.contains('Cloud') &&
        (html.contains('Steam Cloud') ||
            html.contains('OneDrive') ||
            html.contains('GOG Galaxy'));

    return SaveGameInfo(
      locations: locations,
      cloudSync: cloudSync,
      cloudServices: _extractCloudServices(html),
    );
  }

  String? _extractSection(String html, String sectionName) {
    final id = sectionName.toLowerCase().replaceAll(' ', '_');
    final headerPattern = RegExp(
      'id="$id"[^>]*>.*?</h[23]>(.*?)(?=<h[23]|\$)',
      dotAll: true,
      caseSensitive: false,
    );
    final match = headerPattern.firstMatch(html);
    return match?.group(1);
  }

  List<String> _extractPaths(String section, String platform) {
    final paths = <String>[];
    final pathPattern = RegExp(
      r'((?:~?[/\\]?[A-Za-z0-9_\.\s]+[/\\])+[A-Za-z0-9_\.\*]+)',
    );

    for (final match in pathPattern.allMatches(section)) {
      var path = match.group(0)?.trim() ?? '';
      if (path.isNotEmpty && !path.startsWith('http')) {
        // Clean up the path
        path = path.replaceAll(RegExp(r'<[^>]+>'), '');
        path = path.replaceAll('&amp;', '&');
        paths.add(path);
      }
    }

    return paths;
  }

  SaveLocationType _determineLocationType(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.contains('save') || lowerPath.contains('saves')) {
      return SaveLocationType.saves;
    } else if (lowerPath.contains('config') || lowerPath.contains('settings')) {
      return SaveLocationType.config;
    } else if (lowerPath.contains('appdata') || lowerPath.contains('local')) {
      return SaveLocationType.appData;
    } else if (lowerPath.contains('documents')) {
      return SaveLocationType.documents;
    }
    return SaveLocationType.other;
  }

  List<String> _extractCloudServices(String html) {
    final services = <String>[];
    if (html.contains('Steam Cloud')) services.add('Steam Cloud');
    if (html.contains('GOG Galaxy')) services.add('GOG Galaxy');
    if (html.contains('OneDrive')) services.add('OneDrive');
    if (html.contains('Epic Games Store')) services.add('Epic Cloud');
    return services;
  }

  /// Expand environment variables and ~ in paths
  String expandPath(String path) {
    var expanded = path;

    // Expand ~ to user profile
    expanded = expanded.replaceAll(
      RegExp(r'^~[/\\]'),
      '${Platform.environment['USERPROFILE'] ?? ''}\\',
    );

    // Expand %APPDATA%
    expanded = expanded.replaceAll(
      '%APPDATA%',
      Platform.environment['APPDATA'] ?? '',
    );

    // Expand %LOCALAPPDATA%
    expanded = expanded.replaceAll(
      '%LOCALAPPDATA%',
      Platform.environment['LOCALAPPDATA'] ?? '',
    );

    // Expand %USERPROFILE%
    expanded = expanded.replaceAll(
      '%USERPROFILE%',
      Platform.environment['USERPROFILE'] ?? '',
    );

    // Expand %DOCUMENTS%
    expanded = expanded.replaceAll(
      '%DOCUMENTS%',
      '${Platform.environment['USERPROFILE'] ?? ''}\\Documents',
    );

    return expanded;
  }
}

class PcgamingwikiResult {
  final String name;
  final String url;

  PcgamingwikiResult({
    required this.name,
    required this.url,
  });
}

class SaveGameInfo {
  final List<SaveLocation> locations;
  final bool cloudSync;
  final List<String> cloudServices;

  SaveGameInfo({
    required this.locations,
    this.cloudSync = false,
    this.cloudServices = const [],
  });
}

class SaveLocation {
  final String platform;
  final String path;
  final SaveLocationType type;

  SaveLocation({
    required this.platform,
    required this.path,
    required this.type,
  });
}

enum SaveLocationType {
  saves,
  config,
  appData,
  documents,
  other,
}
