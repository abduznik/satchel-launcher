import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:hive/hive.dart';

/// Portable drive service. Finds the drive root by walking up from the
/// executable looking for our Config/ folder, then uses ~/ notation
/// (where ~ = drive root) for all portable paths.
///
/// Drive layout (example):
///   H:/
///   +-- Config/          (signature folder, created on setup)
///   +-- Games/
///   +-- Saves/
///   +-- ProjectIndie/    (appDir, where exe lives)
///       +-- project_indie.exe
///       +-- thirdparty/
///
/// ~/Games/Foo  resolves to  H:/Games/Foo
/// Works identically on Windows, Wine, Proton, Crossover.
class DriveService {
  static String? _cachedAppDir;
  static String? _cachedDriveRoot;

  /// The directory containing the running executable.
  static String get appDir {
    if (_cachedAppDir != null) return _cachedAppDir!;
    _cachedAppDir = p.dirname(Platform.resolvedExecutable);
    print('[DriveService] appDir = $_cachedAppDir');
    return _cachedAppDir!;
  }

  /// Finds the drive root by walking up from appDir looking for Config/.
  /// This is flexible — works whether the app is at H:/ProjectIndie/
  /// or H:/apps/myapps/ProjectIndie/ or anywhere else on the drive.
  static String get driveRoot {
    if (_cachedDriveRoot != null) return _cachedDriveRoot!;
    _cachedDriveRoot = _findDriveRoot();
    print('[DriveService] driveRoot = $_cachedDriveRoot');
    return _cachedDriveRoot!;
  }

  static String _findDriveRoot() {
    var dir = appDir;

    // Walk up looking for Config/ folder (our setup wizard creates this).
    // Also accept Games/ or Saves/ as signatures in case Config wasn't created yet.
    for (var i = 0; i < 10; i++) {
      if (_isDriveRoot(dir)) {
        print('[DriveService] Drive root found at: $dir');
        return dir;
      }
      final parent = p.dirname(dir);
      if (parent == dir) break; // filesystem root
      dir = parent;
    }

    // Fallback: one level up from appDir (original assumption)
    print('[DriveService] Drive root fallback: one level up from appDir');
    return p.dirname(appDir);
  }

  /// Checks if a directory looks like the drive root.
  /// Heuristics: contains Config/, or both Games/ and Saves/.
  static bool _isDriveRoot(String dir) {
    if (Directory(p.join(dir, 'Config')).existsSync()) {
      return true;
    }
    if (Directory(p.join(dir, 'Games')).existsSync() &&
        Directory(p.join(dir, 'Saves')).existsSync()) {
      return true;
    }
    return false;
  }

  /// Resolves a ~/path to an absolute path against the drive root.
  /// ~/Games/Foo  →  H:/Games/Foo
  static String resolvePortable(String portablePath) {
    if (portablePath.startsWith('~/')) {
      return p.join(driveRoot, portablePath.substring(2));
    }
    return portablePath;
  }

  /// Converts an absolute path to ~/ notation if it's under the drive root.
  /// H:/Games/Foo  →  ~/Games/Foo
  /// C:/Users/me   →  C:/Users/me  (outside drive, kept absolute)
  static String toPortable(String absolutePath) {
    final normPath = absolutePath.replaceAll('\\', '/').toLowerCase();
    final normRoot = driveRoot.replaceAll('\\', '/').toLowerCase();

    if (normPath.startsWith(normRoot)) {
      var rel = absolutePath.substring(driveRoot.length);
      if (rel.startsWith('\\') || rel.startsWith('/')) {
        rel = rel.substring(1);
      }
      return '~/${rel.replaceAll('\\', '/')}';
    }
    // Outside drive root — return as-is
    return absolutePath.replaceAll('\\', '/');
  }

  static String get configPath => p.join(driveRoot, 'Config');
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
    // Default: ~/Saves
    return p.join(driveRoot, 'Saves');
  }

  static Future<void> ensureDirectories() async {
    final dir = Directory(configPath);
    if (!await dir.exists()) {
      print('[DriveService] Creating config dir: $configPath');
      await dir.create(recursive: true);
    }
  }
}
