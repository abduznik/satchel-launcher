import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:hive/hive.dart';

class DriveService {
  static String? _cachedAppDir;

  static String get appDir {
    if (_cachedAppDir != null) return _cachedAppDir!;
    _cachedAppDir = p.dirname(Platform.resolvedExecutable);
    print('[DriveService] appDir = $_cachedAppDir');
    return _cachedAppDir!;
  }

  static String get configPath => p.join(appDir, 'Config');
  static String get thirdpartyPath => p.join(appDir, 'thirdparty');
  static String get omniSaveExe => p.join(thirdpartyPath, 'OmniSave.exe');

  static String get savesPath {
    final box = Hive.box('settings');
    final saved = box.get('settings');
    if (saved != null) {
      final map = Map<String, dynamic>.from(saved);
      if (map['savesPath'] != null && (map['savesPath'] as String).isNotEmpty) {
        return map['savesPath'];
      }
    }
    return p.join(p.dirname(appDir), 'Saves');
  }

  static Future<void> ensureDirectories() async {
    final dir = Directory(configPath);
    if (!await dir.exists()) {
      print('[DriveService] Creating config dir: $configPath');
      await dir.create(recursive: true);
    }
  }
}
