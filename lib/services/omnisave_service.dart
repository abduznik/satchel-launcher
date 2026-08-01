import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../models/game.dart';
import 'drive_service.dart';
import 'process_tracker.dart';

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
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
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

    // Relative path from the game folder to the exe (e.g. "bin/game.exe").
    // OmniSave sets its working dir to the game folder, so a game whose
    // binary lives in a subfolder must be launched with the relative path,
    // not just the bare filename.
    final relExe = p.relative(game.exePath, from: game.folderPath);
    final gameSavesDir = p.join(savesBasePath, game.name);

    String resolvedLocalPath;
    if (localSavePath != null && localSavePath.isNotEmpty) {
      resolvedLocalPath = localSavePath;
    } else {
      resolvedLocalPath = _defaultSavePath(game);
    }

    final iniContent = '[OmniSave]\n'
        'Launch_Command=$relExe\n'
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
    // Use ~/Saves/<GameName> — portable across PCs and mount points.
    return p.join(DriveService.savesPath, game.name);
  }

  /// Launches the game via OmniSave if the exe is available.
  /// Returns the OmniSave Process handle for tracking, or null if
  /// OmniSave.exe was not found (caller should fall back to direct launch).
  Future<Process?> launchGame(
    Game game, {
    String? localSavePath,
    String? gameArgs,
  }) async {
    await generateConfig(game,
        localSavePath: localSavePath, gameArgs: gameArgs);

    // Extract OmniSave.exe into the game folder — it must sit next to OmniSave.ini
    final omniSavePath = await _extractOmniSave(game.folderPath);
    if (omniSavePath == null) {
      print(
          '[OmniSave] OmniSave.exe unavailable — falling back to direct launch');
      return null;
    }

    print('[OmniSave] Launching via OmniSave: $omniSavePath');
    try {
      final process = await Process.start(
        omniSavePath,
        [],
        workingDirectory: game.folderPath,
        mode: ProcessStartMode.detached,
      );
      return process;
    } catch (e) {
      print('[OmniSave] Failed to launch: $e');
      return null;
    }
  }

  /// Waits for OmniSave to finish its work (sync saves, launch game, cleanup).
  /// OmniSave syncs saves to the drive, launches the game, then exits.
  /// We wait for the OmniSave process to exit to ensure saves are synced.
  static Future<void> waitForSync(ProcessTracker tracker,
      {Duration timeout = const Duration(seconds: 30)}) async {
    print('[OmniSave] Waiting for OmniSave to finish...');
    try {
      await tracker.whenExited.timeout(timeout);
      print('[OmniSave] OmniSave finished');
    } on TimeoutException {
      print('[OmniSave] Timeout waiting for OmniSave — proceeding anyway');
    }
  }

  Future<void> cleanupAfterLaunch(Game game) async {
    // Remove OmniSave.exe and OmniSave.ini from the game folder after use.
    // Never throws — cleanup must not block the "back to PLAY" state reset.
    for (final name in ['OmniSave.exe', 'OmniSave.ini']) {
      try {
        final f = File(p.join(game.folderPath, name));
        if (await f.exists()) await f.delete();
      } catch (e) {
        print('[OmniSave] Cleanup failed for $name: $e');
      }
    }
  }
}
