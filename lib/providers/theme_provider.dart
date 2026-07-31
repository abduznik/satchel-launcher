import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

enum AppTheme {
  defaultDark,
  light,
  crimson,
  roseGold,
  neonCyan,
  oledBlack,
}

class ThemePreset {
  final String name;
  final ThemeData theme;

  const ThemePreset({required this.name, required this.theme});
}

class ThemeProvider extends ChangeNotifier {
  AppTheme _currentTheme = AppTheme.defaultDark;
  late Box _settingsBox;

  ThemeProvider() {
    _settingsBox = Hive.box('settings');
    _loadTheme();
  }

  AppTheme get currentTheme => _currentTheme;

  ThemeData get theme => _getThemePreset(_currentTheme).theme;

  ThemePreset _getThemePreset(AppTheme theme) {
    switch (theme) {
      case AppTheme.defaultDark:
        return _defaultDarkTheme();
      case AppTheme.light:
        return _lightTheme();
      case AppTheme.crimson:
        return _crimsonTheme();
      case AppTheme.roseGold:
        return _roseGoldTheme();
      case AppTheme.neonCyan:
        return _neonCyanTheme();
      case AppTheme.oledBlack:
        return _oledBlackTheme();
    }
  }

  ThemePreset _defaultDarkTheme() {
    return ThemePreset(
      name: 'Default Dark',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0f0f23),
        cardTheme: CardThemeData(
          color: const Color(0xFF16213e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1a1a2e),
          elevation: 0,
        ),
      ),
    );
  }

  ThemePreset _lightTheme() {
    return ThemePreset(
      name: 'Light',
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
      ),
    );
  }

  ThemePreset _crimsonTheme() {
    return ThemePreset(
      name: 'Crimson',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.redAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1a0a0a),
        cardTheme: CardThemeData(
          color: const Color(0xFF2d1515),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2d1515),
          elevation: 0,
        ),
      ),
    );
  }

  ThemePreset _roseGoldTheme() {
    return ThemePreset(
      name: 'Rose Gold',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pinkAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1a1015),
        cardTheme: CardThemeData(
          color: const Color(0xFF2d1a25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2d1a25),
          elevation: 0,
        ),
      ),
    );
  }

  ThemePreset _neonCyanTheme() {
    return ThemePreset(
      name: 'Neon Cyan',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0a1a1a),
        cardTheme: CardThemeData(
          color: const Color(0xFF152d2d),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF152d2d),
          elevation: 0,
        ),
      ),
    );
  }

  ThemePreset _oledBlackTheme() {
    return ThemePreset(
      name: 'OLED Black',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        cardTheme: CardThemeData(
          color: const Color(0xFF0a0a0a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
      ),
    );
  }

  void _loadTheme() {
    final themeIndex = _settingsBox.get('theme', defaultValue: 0);
    _currentTheme = AppTheme.values[themeIndex];
  }

  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    await _settingsBox.put('theme', theme.index);
    notifyListeners();
  }

  List<AppTheme> get availableThemes => AppTheme.values;
}

final themeProvider = ChangeNotifierProvider<ThemeProvider>((ref) {
  return ThemeProvider();
});
