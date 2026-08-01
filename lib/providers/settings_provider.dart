import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../services/drive_service.dart';

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class AppSettings {
  final bool autoStartEnabled;
  final bool autoScanOnStartup;
  final String gamesPath;   // Stored as ~/Games (relative to drive root)
  final String savesPath;   // Stored as ~/Saves (relative to drive root)

  AppSettings({
    this.autoStartEnabled = true,
    this.autoScanOnStartup = true,
    required this.gamesPath,
    required this.savesPath,
  });

  /// Returns the absolute games path resolved against the current drive root.
  String get resolvedGamesPath => DriveService.resolvePortable(gamesPath);

  /// Returns the absolute saves path resolved against the current drive root.
  String get resolvedSavesPath => DriveService.resolvePortable(savesPath);

  Map<String, dynamic> toJson() => {
    'autoStartEnabled': autoStartEnabled,
    'autoScanOnStartup': autoScanOnStartup,
    'gamesPath': gamesPath,
    'savesPath': savesPath,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    // Handle both legacy absolute paths and new ~/ paths
    var gamesPath = json['gamesPath'] ?? '';
    var savesPath = json['savesPath'] ?? '';

    // Migrate legacy absolute paths to ~/ notation
    if (gamesPath.isNotEmpty && !gamesPath.startsWith('~/')) {
      gamesPath = DriveService.toPortable(gamesPath);
    }
    if (savesPath.isNotEmpty && !savesPath.startsWith('~/')) {
      savesPath = DriveService.toPortable(savesPath);
    }

    return AppSettings(
      autoStartEnabled: json['autoStartEnabled'] ?? true,
      autoScanOnStartup: json['autoScanOnStartup'] ?? true,
      gamesPath: gamesPath,
      savesPath: savesPath,
    );
  }

  AppSettings copyWith({
    bool? autoStartEnabled,
    bool? autoScanOnStartup,
    String? gamesPath,
    String? savesPath,
  }) {
    return AppSettings(
      autoStartEnabled: autoStartEnabled ?? this.autoStartEnabled,
      autoScanOnStartup: autoScanOnStartup ?? this.autoScanOnStartup,
      gamesPath: gamesPath ?? this.gamesPath,
      savesPath: savesPath ?? this.savesPath,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  late final Box _settingsBox;

  SettingsNotifier()
      : super(AppSettings(gamesPath: '', savesPath: '')) {
    _settingsBox = Hive.box('settings');
    _loadSettings();
  }

  void _loadSettings() {
    final data = _settingsBox.get('settings');
    if (data != null) {
      final map = Map<String, dynamic>.from(data);
      print('[SettingsNotifier] Loaded: $map');
      state = AppSettings.fromJson(map);
    } else {
      print('[SettingsNotifier] No saved settings');
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    // Ensure paths are stored as ~/ notation
    var gamesPath = newSettings.gamesPath;
    var savesPath = newSettings.savesPath;
    if (gamesPath.isNotEmpty && !gamesPath.startsWith('~/')) {
      gamesPath = DriveService.toPortable(gamesPath);
    }
    if (savesPath.isNotEmpty && !savesPath.startsWith('~/')) {
      savesPath = DriveService.toPortable(savesPath);
    }
    final normalized = newSettings.copyWith(
      gamesPath: gamesPath,
      savesPath: savesPath,
    );
    state = normalized;
    await _settingsBox.put('settings', normalized.toJson());
    print('[SettingsNotifier] Saved: ${normalized.toJson()}');
  }
}
