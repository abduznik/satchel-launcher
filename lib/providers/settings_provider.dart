import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class AppSettings {
  final bool autoStartEnabled;
  final bool autoScanOnStartup;
  final String gamesPath;
  final String savesPath;

  AppSettings({
    this.autoStartEnabled = true,
    this.autoScanOnStartup = true,
    this.gamesPath = 'H:\\Games',
    this.savesPath = 'H:\\Saves',
  });

  Map<String, dynamic> toJson() => {
    'autoStartEnabled': autoStartEnabled,
    'autoScanOnStartup': autoScanOnStartup,
    'gamesPath': gamesPath,
    'savesPath': savesPath,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    autoStartEnabled: json['autoStartEnabled'] ?? true,
    autoScanOnStartup: json['autoScanOnStartup'] ?? true,
    gamesPath: json['gamesPath'] ?? 'H:\\Games',
    savesPath: json['savesPath'] ?? 'H:\\Saves',
  );

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

  SettingsNotifier() : super(AppSettings()) {
    _settingsBox = Hive.box('settings');
    _loadSettings();
  }

  void _loadSettings() {
    final data = _settingsBox.get('settings');
    if (data != null) {
      state = AppSettings.fromJson(Map<String, dynamic>.from(data));
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    state = newSettings;
    await _settingsBox.put('settings', newSettings.toJson());
  }
}
