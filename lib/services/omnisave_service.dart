import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/game.dart';
import 'pcgamingwiki_service.dart';

class OmniSaveService {
  final String savesBasePath;
  final PcgamingwikiService _pcgamingwiki;

  OmniSaveService({
    required this.savesBasePath,
    PcgamingwikiService? pcgamingwiki,
  }) : _pcgamingwiki = pcgamingwiki ?? PcgamingwikiService();

  /// Path to OmniSave.exe bundled in thirdparty/
  String get _bundledOmniSavePath {
    // In development, use thirdparty/ folder
    // In production, use the app's asset directory
    final appDir = p.dirname(p.dirname(p.dirname(Platform.resolvedExecutable)));
    final thirdpartyPath = p.join(appDir, 'thirdparty', 'OmniSave.exe');

    // Fallback to development path
    if (!File(thirdpartyPath).existsSync()) {
      return p.join(Directory.current.path, 'thirdparty', 'OmniSave.exe');
    }

    return thirdpartyPath;
  }

  /// Generate OmniSave.ini with auto-detected or provided save path
  Future<void> generateConfig(
    Game game, {
    String? localSavePath,
    String? gameArgs,
  }) async {
    final indieDir = Directory(p.join(game.folderPath, '.indie'));
    if (!await indieDir.exists()) {
      await indieDir.create(recursive: true);
    }

    final exeName = p.basename(game.exePath);
    final gameSavesDir = p.join(savesBasePath, game.name);

    // Use provided path or attempt PCGamingWiki detection
    String resolvedLocalPath;
    if (localSavePath != null && localSavePath.isNotEmpty) {
      resolvedLocalPath = localSavePath;
    } else {
      resolvedLocalPath = await _detectSavePath(game);
    }

    final iniContent = '''
[OmniSave]
Launch_Command=$exeName
Launch_Args=${gameArgs ?? ''}
Local_Path=$resolvedLocalPath
Remote_Path=$gameSavesDir
''';

    final iniFile = File(p.join(indieDir.path, 'omnisave.ini'));
    await iniFile.writeAsString(iniContent);

    // Ensure saves directory exists
    final savesDir = Directory(gameSavesDir);
    if (!await savesDir.exists()) {
      await savesDir.create(recursive: true);
    }
  }

  /// Attempt to detect save path using PCGamingWiki
  Future<String> _detectSavePath(Game game) async {
    try {
      // Search PCGamingWiki for the game
      final results = await _pcgamingwiki.search(game.name);
      if (results.isEmpty) {
        return _defaultSavePath(game);
      }

      // Try to get save locations from the first result
      final saveInfo = await _pcgamingwiki.getSaveLocations(results.first.url);
      if (saveInfo == null || saveInfo.locations.isEmpty) {
        return _defaultSavePath(game);
      }

      // Find Windows save location
      final windowsSave = saveInfo.locations.firstWhere(
        (loc) => loc.platform == 'Windows' && loc.type == SaveLocationType.saves,
        orElse: () => saveInfo.locations.first,
      );

      // Expand the path
      return _pcgamingwiki.expandPath(windowsSave.path);
    } catch (_) {
      return _defaultSavePath(game);
    }
  }

  String _defaultSavePath(Game game) {
    return p.join(
      Platform.environment['USERPROFILE'] ?? '',
      'Documents',
      'Saves',
      game.name,
    );
  }

  /// Launch game via OmniSave with full lifecycle management
  Future<void> launchGame(
    Game game, {
    String? localSavePath,
    String? gameArgs,
  }) async {
    // Generate fresh config
    await generateConfig(game, localSavePath: localSavePath, gameArgs: gameArgs);

    // Copy OmniSave.exe to game's .indie directory for isolated execution
    final indieOmniSave = File(
      p.join(game.folderPath, '.indie', 'OmniSave.exe'),
    );
    if (!await indieOmniSave.exists()) {
      await File(_bundledOmniSavePath).copy(indieOmniSave.path);
    }

    // Copy the ini file next to OmniSave.exe
    final sourceIni = File(p.join(game.folderPath, '.indie', 'omnisave.ini'));
    final destIni = File(
      p.join(game.folderPath, '.indie', 'OmniSave.ini'),
    );
    if (await sourceIni.exists()) {
      await sourceIni.copy(destIni.path);
    }

    // Launch OmniSave.exe which will handle the full lifecycle
    await Process.start(
      indieOmniSave.path,
      [],
      workingDirectory: game.folderPath,
      mode: ProcessStartMode.normal,
    );
  }

  /// Clean up OmniSave files after launch
  Future<void> cleanupAfterLaunch(Game game) async {
    final indieOmniSave = File(
      p.join(game.folderPath, '.indie', 'OmniSave.exe'),
    );
    if (await indieOmniSave.exists()) {
      await indieOmniSave.delete();
    }

    final iniCopy = File(
      p.join(game.folderPath, '.indie', 'OmniSave.ini'),
    );
    if (await iniCopy.exists()) {
      await iniCopy.delete();
    }
  }
}
