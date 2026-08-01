import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/game.dart';
import 'package:uuid/uuid.dart';

class GameScanner {
  final String gamesPath;

  GameScanner({required this.gamesPath});

  Future<List<Game>> scan({
    void Function(int current, int total, String folderName)? onProgress,
  }) async {
    print('[GameScanner] Scanning: $gamesPath');
    final gamesDir = Directory(gamesPath);
    if (!await gamesDir.exists()) {
      print('[GameScanner] Games directory does not exist: $gamesPath');
      return [];
    }

    final games = <Game>[];
    final entries = await gamesDir.list().toList();
    print('[GameScanner] Found ${entries.length} entries in Games dir');

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      onProgress?.call(i + 1, entries.length, p.basename(entry.path));
      if (entry is Directory) {
        print('[GameScanner] Checking folder: ${p.basename(entry.path)}');
        final game = await _scanFolder(entry.path);
        if (game != null) {
          print(
              '[GameScanner] ✓ Detected game: ${game.name} → ${game.exePath}');
          games.add(game);
        } else {
          print(
              '[GameScanner] ✗ Skipped: ${p.basename(entry.path)} (no exe found)');
        }
      }
    }

    print('[GameScanner] Total games found: ${games.length}');
    return games;
  }

  Future<Game?> _scanFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return null;

    final folderName = p.basename(folderPath);

    // Check for .indie metadata
    final metaFile = File(p.join(folderPath, '.indie', 'meta.json'));
    GameMetadata? metadata;
    String? customName;
    String? savedCoverPath;

    String? savedBannerPath;
    if (await metaFile.exists()) {
      try {
        final json = await metaFile.readAsString();
        final data = _parseJson(json);
        metadata = GameMetadata.fromJson(data);
        customName = data['customName'] as String?;
        savedCoverPath = data['coverPath'] as String?;
        savedBannerPath = data['bannerPath'] as String?;
        print('[GameScanner] Loaded metadata for $folderName: '
            'screenshots=${metadata.screenshots.length} '
            'videos=${metadata.videos.length}');
      } catch (e) {
        print('[GameScanner] Failed to parse meta.json for $folderName: $e');
      }
    }

    // Find executable using smart detection
    final exePath = await findMainExe(folderPath, folderName);
    if (exePath == null) {
      print('[GameScanner] No exe found in $folderPath');
      return null;
    }

    // Determine cover path
    String? coverPath;
    if (savedCoverPath != null && await File(savedCoverPath).exists()) {
      coverPath = savedCoverPath;
    } else {
      final localCover = File(p.join(folderPath, '.indie', 'cover.jpg'));
      if (await localCover.exists()) coverPath = localCover.path;
    }

    // Determine banner path
    String? bannerPath;
    if (savedBannerPath != null && await File(savedBannerPath).exists()) {
      bannerPath = savedBannerPath;
    } else {
      final localBanner = File(p.join(folderPath, '.indie', 'banner.jpg'));
      if (await localBanner.exists()) bannerPath = localBanner.path;
    }

    // Filter out any screenshot paths that no longer exist on disk
    if (metadata != null && metadata.screenshots.isNotEmpty) {
      final validScreenshots = <String>[];
      for (final path in metadata.screenshots) {
        if (await File(path).exists()) {
          validScreenshots.add(path);
        } else {
          print('[GameScanner] Screenshot missing, skipping: $path');
        }
      }
      if (validScreenshots.length != metadata.screenshots.length) {
        metadata = metadata.copyWith(screenshots: validScreenshots);
      }
    }

    return Game(
      id: _generateId(folderPath),
      name: folderName,
      customName: customName,
      folderPath: folderPath,
      exePath: exePath,
      coverPath: coverPath,
      bannerPath: bannerPath,
      metadata: metadata,
    );
  }

  /// Smart executable detection. Searches recursively, skips junk executables,
  /// token-scores against [gameName], and falls back to largest .exe.
  static Future<String?> findMainExe(String folderPath, String gameName) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return null;

    const launchableExtensions = ['.exe', '.bat', '.cmd'];
    const skipList = [
      'uninstall',
      'uninst',
      'setup',
      'install',
      'redist',
      'vc_redist',
      'vcredist',
      'directx',
      'dxsetup',
      'dotnet',
      'crashreport',
      'crashhandler',
      'bugsplat',
      'upc',
      'easyanticheat',
      'battleye',
      'launcher_helper',
    ];

    final exeFiles = <File>[];

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (!launchableExtensions.contains(ext)) continue;

        final basename = p.basename(entity.path);
        // Skip macOS resource forks
        if (basename.startsWith('._')) continue;

        // Skip files inside __macosx or _commonredist
        final relPath = entity.path.substring(folderPath.length).toLowerCase();
        if (relPath.contains('__macosx') || relPath.contains('_commonredist')) {
          continue;
        }

        // Skip known junk executables
        final nameLower = basename.toLowerCase();
        if (skipList.any((s) => nameLower.contains(s))) {
          continue;
        }

        exeFiles.add(entity);
      }
    }

    if (exeFiles.isEmpty) return null;

    // Token-score against game name
    final hintTokens = _tokenize(gameName);
    if (hintTokens.isNotEmpty) {
      int bestScore = 0;
      File? bestMatch;

      for (final exe in exeFiles) {
        final exeTokens = _tokenize(p.basenameWithoutExtension(exe.path));
        int score = 0;
        for (final token in hintTokens) {
          if (exeTokens.any((t) => t.contains(token) || token.contains(t))) {
            score++;
          }
        }
        if (score > bestScore) {
          bestScore = score;
          bestMatch = exe;
        }
      }

      if (bestMatch != null && bestScore > 0) return bestMatch.path;
    }

    // Fallback: largest .exe by file size
    final exes =
        exeFiles.where((f) => f.path.toLowerCase().endsWith('.exe')).toList();
    final candidates = exes.isNotEmpty ? exes : exeFiles;

    File? largest;
    int largestSize = 0;
    for (final exe in candidates) {
      final size = await exe.length();
      if (size > largestSize) {
        largestSize = size;
        largest = exe;
      }
    }

    return largest?.path;
  }

  /// Tokenizes a name for fuzzy matching.
  static Set<String> _tokenize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2)
        .toSet();
  }

  String _generateId(String path) {
    return const Uuid().v5('6ba7b810-9dad-11d1-80b4-00c04fd430c8', path);
  }

  Map<String, dynamic> _parseJson(String jsonStr) {
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
