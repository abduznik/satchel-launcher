import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../models/game.dart';
import 'drive_service.dart';

class OmniSaveService {
  final String savesBasePath;

  OmniSaveService({
    String? savesBasePath,
  }) : savesBasePath = savesBasePath ?? DriveService.savesPath;

  /// Extracts OmniSave.exe from Flutter assets to the .indie folder.
  /// Returns the path if successful, null if the asset isn't bundled.
  Future<String?> _extractOmniSave(String indieDirPath) async {
    final destFile = File(p.join(indieDirPath, 'OmniSave.exe'));
    if (await destFile.exists()) return destFile.path;
    try {
      final data = await rootBundle.load('thirdparty/OmniSave.exe');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await destFile.writeAsBytes(bytes);
      print('[OmniSave] Extracted OmniSave.exe to ${destFile.path}');
      return destFile.path;
    } catch (e) {
      print('[OmniSave] OmniSave.exe not found in assets: $e');
      return null;
    }
  }

  Future<void> generateConfig(
    Game game, {
    String? localSavePath,
    String? gameArgs,
  }) async {
    final indieDir = Directory(p.join(game.folderPath, '.indie'));
    if (!await indieDir.exists()) {
      await indieDir.create(recursive: true);
    }

    // Just the exe filename — OmniSave sets working dir to the game folder and launches from there
    final exeName = p.basename(game.exePath);
    final gameSavesDir = p.join(savesBasePath, game.name);

    String resolvedLocalPath;
    if (localSavePath != null && localSavePath.isNotEmpty) {
      resolvedLocalPath = localSavePath;
    } else {
      resolvedLocalPath = _defaultSavePath(game);
    }

    final iniContent = '[OmniSave]\n'
        'Launch_Command=$exeName\n'
        'Launch_Args=${gameArgs ?? ''}\n'
        'Local_Path=$resolvedLocalPath\n'
        'Remote_Path=$gameSavesDir\n';

    // Write OmniSave.ini to the game folder — OmniSave looks for it next to itself
    final iniFile = File(p.join(game.folderPath, 'OmniSave.ini'));
    await iniFile.writeAsString(iniContent);

    // Also keep a copy in .indie/ for reference
    final indieIni = File(p.join(indieDir.path, 'omnisave.ini'));
    await indieIni.writeAsString(iniContent);

    final savesDir = Directory(gameSavesDir);
    if (!await savesDir.exists()) {
      await savesDir.create(recursive: true);
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

  /// Launches the game via OmniSave if the exe is available.
  /// Returns true if launched via OmniSave, false if OmniSave.exe was not found
  /// (caller should fall back to direct launch).
  Future<bool> launchGame(
    Game game, {
    String? localSavePath,
    String? gameArgs,
  }) async {
    await generateConfig(game, localSavePath: localSavePath, gameArgs: gameArgs);

    // Extract OmniSave.exe into the game folder — it must sit next to OmniSave.ini
    final omniSavePath = await _extractOmniSave(game.folderPath);
    if (omniSavePath == null) {
      print('[OmniSave] OmniSave.exe unavailable — falling back to direct launch');
      return false;
    }

    print('[OmniSave] Launching via OmniSave: $omniSavePath');
    await Process.start(
      omniSavePath,
      [],
      workingDirectory: game.folderPath,
      mode: ProcessStartMode.detached,
    );
    return true;
  }

  Future<void> cleanupAfterLaunch(Game game) async {
    // Remove OmniSave.exe and OmniSave.ini from the game folder after use
    for (final name in ['OmniSave.exe', 'OmniSave.ini']) {
      final f = File(p.join(game.folderPath, name));
      if (await f.exists()) await f.delete();
    }
  }
}
