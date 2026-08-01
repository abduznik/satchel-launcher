import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:hive/hive.dart';
import 'drive_service.dart';

/// Detects existing data on the drive and offers migration when
/// the user resets setup or moves to a new PC.
class MigrationService {
  /// Scans the drive for existing data that could be migrated.
  /// Returns a summary of what was found.
  static Future<MigrationInfo> scan() async {
    final root = DriveService.driveRoot;
    final info = MigrationInfo();

    // Check for existing Config/ with data
    final configDir = Directory(DriveService.configPath);
    if (await configDir.exists()) {
      // Check for API keys
      final keysFile = File(p.join(DriveService.configPath, 'keys.enc'));
      info.hasApiKeys = await keysFile.exists();

      // Check for settings
      final settingsFile = File(p.join(DriveService.configPath, 'settings.hive'));
      info.hasSettings = await settingsFile.exists();

      // Check for games database
      final gamesFile = File(p.join(DriveService.configPath, 'games.hive'));
      info.hasGamesDb = await gamesFile.exists();
    }

    // Check for existing Games/ folder
    final gamesDir = Directory(p.join(root, 'Games'));
    info.hasGamesFolder = await gamesDir.exists();
    if (info.hasGamesFolder) {
      // Count game folders
      try {
        final entries = await gamesDir.list().toList();
        info.gameCount = entries.whereType<Directory>().length;
      } catch (_) {}
    }

    // Check for existing Saves/
    final savesDir = Directory(p.join(root, 'Saves'));
    info.hasSavesFolder = await savesDir.exists();

    // Check for OmniSave configs in game folders
    if (info.hasGamesFolder) {
      try {
        final gamesDir = Directory(p.join(root, 'Games'));
        await for (final entity in gamesDir.list()) {
          if (entity is Directory) {
            final omniIni = File(p.join(entity.path, 'OmniSave.ini'));
            if (await omniIni.exists()) {
              info.omnisaveConfigs++;
            }
            final indieDir = Directory(p.join(entity.path, '.indie'));
            if (await indieDir.exists()) {
              info.indieMetadataFolders++;
            }
          }
        }
      } catch (_) {}
    }

    return info;
  }

  /// Migrates data from an existing setup to the current one.
  /// Only copies personal databases (Config/, API keys), NOT game files.
  static Future<MigrationResult> migrate() async {
    final result = MigrationResult();

    try {
      // The Hive boxes are already loaded from Config/ if it exists.
      // Since Config/ lives at the drive root and we detect the drive root
      // by looking for Config/, the data is automatically available.
      //
      // What we need to do:
      // 1. Ensure Config/ directory exists
      await DriveService.ensureDirectories();

      // 2. Re-open Hive boxes (they may have been created fresh)
      // The boxes are already opened in main.dart, so just verify they have data.
      final settingsBox = Hive.box('settings');
      final gamesBox = Hive.box('games');

      final settingsData = settingsBox.get('settings');
      if (settingsData != null) {
        result.settingsImported = true;
        print('[Migration] Settings data found and preserved');
      }

      final gamesData = gamesBox.get('games');
      if (gamesData != null) {
        final games = gamesData as List;
        result.gamesImported = games.length;
        print('[Migration] ${games.length} games found in database');
      }

      // 3. Check for API keys (encrypted file)
      final keysFile = File(p.join(DriveService.configPath, 'keys.enc'));
      if (await keysFile.exists()) {
        result.apiKeysImported = true;
        print('[Migration] API keys file found and preserved');
      }

      result.success = true;
    } catch (e) {
      print('[Migration] Error: $e');
      result.success = false;
      result.error = e.toString();
    }

    return result;
  }
}

class MigrationInfo {
  bool hasApiKeys = false;
  bool hasSettings = false;
  bool hasGamesDb = false;
  bool hasGamesFolder = false;
  bool hasSavesFolder = false;
  int gameCount = 0;
  int omnisaveConfigs = 0;
  int indieMetadataFolders = 0;

  bool get hasAnyData =>
      hasApiKeys || hasSettings || hasGamesDb || gameCount > 0;

  String describe() {
    final parts = <String>[];
    if (hasSettings) parts.add('Settings');
    if (hasApiKeys) parts.add('API keys');
    if (gameCount > 0) parts.add('$gameCount games');
    if (omnisaveConfigs > 0) parts.add('$omnisaveConfigs OmniSave configs');
    if (indieMetadataFolders > 0) parts.add('$indieMetadataFolders game metadata folders');
    if (hasSavesFolder) parts.add('Saves folder');
    return parts.isEmpty ? 'No existing data found' : parts.join(', ');
  }
}

class MigrationResult {
  bool success = false;
  bool settingsImported = false;
  bool apiKeysImported = false;
  int gamesImported = 0;
  String? error;
}
