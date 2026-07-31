import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/game.dart';
import 'package:uuid/uuid.dart';

class GameScanner {
  final String gamesPath;

  GameScanner({required this.gamesPath});

  Future<List<Game>> scan() async {
    final gamesDir = Directory(gamesPath);
    if (!await gamesDir.exists()) {
      return [];
    }

    final games = <Game>[];
    final folders = await gamesDir.list().where((e) => e is Directory).toList();

    for (final folder in folders) {
      final game = await _scanFolder(folder.path);
      if (game != null) {
        games.add(game);
      }
    }

    return games;
  }

  Future<Game?> _scanFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return null;

    final folderName = p.basename(folderPath);

    // Check for .indie metadata first
    final metaFile = File(p.join(folderPath, '.indie', 'meta.json'));
    GameMetadata? metadata;
    String? savedCoverPath;

    if (await metaFile.exists()) {
      try {
        final json = await metaFile.readAsString();
        final data = _parseJson(json);
        metadata = GameMetadata.fromJson(data);
        savedCoverPath = data['coverPath'];
      } catch (_) {}
    }

    // Find the main executable
    final exePath = await _findMainExe(dir);
    if (exePath == null) return null;

    // Determine cover path
    String? coverPath;
    if (savedCoverPath != null && await File(savedCoverPath).exists()) {
      coverPath = savedCoverPath;
    } else {
      final localCover = File(p.join(folderPath, '.indie', 'cover.jpg'));
      if (await localCover.exists()) {
        coverPath = localCover.path;
      }
    }

    return Game(
      id: _generateId(folderPath),
      name: metadata != null && metadata.summary != null
          ? folderName
          : folderName,
      folderPath: folderPath,
      exePath: exePath,
      coverPath: coverPath,
      metadata: metadata,
    );
  }

  Future<String?> _findMainExe(Directory dir) async {
    final files = await dir.list().toList();

    // Look for executable files
    final exes = files
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.exe'))
        .toList();

    if (exes.isEmpty) return null;

    // Prefer common game executable names
    final preferredNames = [
      'game.exe',
      'launch.exe',
      'start.exe',
      'play.exe',
      'main.exe',
      'client.exe',
    ];
    for (final preferred in preferredNames) {
      final match = exes.where(
        (f) => p.basename(f.path).toLowerCase() == preferred,
      );
      if (match.isNotEmpty) return match.first.path;
    }

    // Fall back to first exe found
    return exes.first.path;
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
