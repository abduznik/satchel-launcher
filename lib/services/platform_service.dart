import 'dart:io';
import 'package:path/path.dart' as p;

/// Detects the runtime environment (native Windows, Wine, Proton, Crossover)
/// and provides cross-platform path resolution.
class PlatformService {
  static bool? _cachedIsWine;
  static bool? _cachedIsProton;
  static String? _cachedDriveRoot;
  static String? _cachedUserHome;

  /// Whether we're running under Wine (includes Crossover).
  static bool get isWine {
    if (_cachedIsWine != null) return _cachedIsWine!;
    // Wine sets WINEPREFIX or WINELOADERNOEXEC env vars.
    // Crossover sets CROSSOVER_PREFIX.
    _cachedIsWine = Platform.environment.containsKey('WINEPREFIX') ||
        Platform.environment.containsKey('WINELOADERNOEXEC') ||
        Platform.environment.containsKey('CROSSOVER_PREFIX') ||
        _detectWineDlls();
    print('[PlatformService] isWine = $_cachedIsWine');
    return _cachedIsWine!;
  }

  /// Whether we're running under Proton (Steam Play).
  static bool get isProton {
    if (_cachedIsProton != null) return _cachedIsProton!;
    // Proton sets PROTON_USE_WINED3D, STEAM_COMPAT_DATA_PATH, etc.
    _cachedIsProton = Platform.environment.containsKey('PROTON_USE_WINED3D') ||
        Platform.environment.containsKey('STEAM_COMPAT_DATA_PATH') ||
        Platform.environment.containsKey('PROTON_VERSION');
    print('[PlatformService] isProton = $_cachedIsProton');
    return _cachedIsProton!;
  }

  /// Whether running under any Wine-like environment (Wine, Proton, Crossover).
  static bool get isWinLike => isWine || isProton;

  /// The actual user home directory on the host OS.
  /// On Windows: C:\Users\username
  /// On macOS/Linux via Wine: /Users/username or /home/username
  static String get userHome {
    if (_cachedUserHome != null) return _cachedUserHome!;
    // Prefer HOME on Unix systems (macOS/Linux), fall back to USERPROFILE on Windows.
    _cachedUserHome = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    print('[PlatformService] userHome = $_cachedUserHome');
    return _cachedUserHome!;
  }

  /// Detects Wine by checking for ntdll.dll in the system directory.
  /// This is a heuristic fallback when env vars aren't set.
  static bool _detectWineDlls() {
    if (!Platform.isWindows) return false;
    try {
      // Wine's ntdll.dll is typically in system32 but has different metadata.
      // A simpler check: look for wine_get_version function in ntdll.
      final systemDir = Platform.environment['windir'] ?? r'C:\Windows';
      final ntdll = File(p.join(systemDir, 'System32', 'ntdll.dll'));
      if (ntdll.existsSync()) {
        // Read first 4KB and check for Wine-specific strings
        final bytes = ntdll.readAsBytesSync();
        final text = String.fromCharCodes(bytes);
        return text.contains('Wine') || text.contains('wine');
      }
    } catch (_) {}
    return false;
  }

  /// Finds the drive root by walking up from the executable directory
  /// looking for a Config/ folder (our signature directory).
  /// Works on any OS — just looks for the folder structure.
  static String findDriveRoot() {
    if (_cachedDriveRoot != null) return _cachedDriveRoot!;

    var dir = p.dirname(Platform.resolvedExecutable);

    // Walk up to 5 levels looking for Config/ folder
    for (var i = 0; i < 5; i++) {
      final configDir = Directory(p.join(dir, 'Config'));
      if (configDir.existsSync()) {
        _cachedDriveRoot = dir;
        print('[PlatformService] Drive root found: $dir');
        return dir;
      }
      final parent = p.dirname(dir);
      if (parent == dir) break; // reached filesystem root
      dir = parent;
    }

    // Fallback: use the exe's parent directory (original behavior)
    _cachedDriveRoot = p.dirname(Platform.resolvedExecutable);
    print('[PlatformService] Drive root fallback: $_cachedDriveRoot');
    return _cachedDriveRoot!;
  }

  /// Opens a URL in the default browser, cross-platform.
  static Future<void> openUrl(String url) async {
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', url]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    }
  }

  /// Resolves a Windows-style path to the actual host OS path.
  /// When running under Wine, Windows paths like H:\Games work via Wine's
  /// mount manager, but we need to handle edge cases.
  static String resolvePath(String windowsPath) {
    if (!isWinLike) return windowsPath;

    // Wine automatically maps Windows drive letters to ~/.wine/dosdevices/
    // So H:\Games\foo becomes ~/.wine/dosdevices/h:/Games/foo
    // But Wine also makes the drive letter accessible directly as H:\
    // in the Windows environment. So most paths "just work" under Wine.
    // We just need to make sure the path exists.
    return windowsPath;
  }

  /// Returns the appropriate home directory for portable path conversion.
  /// Used in omnisave_service, save_location_dialog, etc.
  static String get portableHome {
    // When running under Wine/Proton, the Windows USERPROFILE is mapped
    // to the Wine prefix. We want the ACTUAL host home for ~/ notation.
    if (isWinLike && !Platform.isWindows) {
      return userHome;
    }
    return userHome;
  }
}
