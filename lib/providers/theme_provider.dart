import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

enum AppTheme {
  amber,        // NEW default — warm yellow/gold
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
  AppTheme _currentTheme = AppTheme.amber;
  late Box _settingsBox;

  ThemeProvider() {
    _settingsBox = Hive.box('settings');
    _loadTheme();
  }

  AppTheme get currentTheme => _currentTheme;

  ThemeData get theme => _getThemePreset(_currentTheme).theme;

  ThemePreset _getThemePreset(AppTheme theme) {
    switch (theme) {
      case AppTheme.amber:       return _amberTheme();
      case AppTheme.defaultDark: return _defaultDarkTheme();
      case AppTheme.light:       return _lightTheme();
      case AppTheme.crimson:     return _crimsonTheme();
      case AppTheme.roseGold:    return _roseGoldTheme();
      case AppTheme.neonCyan:    return _neonCyanTheme();
      case AppTheme.oledBlack:   return _oledBlackTheme();
    }
  }

  // ── Amber / Gold (default) ─────────────────────────────────────────────
  ThemePreset _amberTheme() {
    return ThemePreset(
      name: 'Amber',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF59E0B),
          secondary: Color(0xFFFBBF24),
          surface: Color(0xFF1A1814),
          onSurface: Color(0xFFF5F0E8),
          outline: Color(0xFF3D3520),
        ),
        scaffoldBackgroundColor: const Color(0xFF12100C),
        cardTheme: const CardThemeData(
          color: Color(0xFF1A1814),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          elevation: 0,
        ),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1A1814), elevation: 0),
        dividerTheme: const DividerThemeData(color: Color(0xFF3D3520), thickness: 1),
      ),
    );
  }

  // ── Default Dark (purple) ──────────────────────────────────────────────
  ThemePreset _defaultDarkTheme() {
    return ThemePreset(
      name: 'Dark',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C3AED),
          secondary: Color(0xFF9F67FF),
          surface: Color(0xFF161622),
          onSurface: Color(0xFFE2E2F0),
          outline: Color(0xFF2E2E45),
        ),
        scaffoldBackgroundColor: const Color(0xFF0E0E16),
        cardTheme: const CardThemeData(
          color: Color(0xFF161622),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          elevation: 0,
        ),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF161622), elevation: 0),
        dividerTheme: const DividerThemeData(color: Color(0xFF2E2E45), thickness: 1),
      ),
    );
  }

  ThemePreset _lightTheme() {
    return ThemePreset(
      name: 'Light',
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFF59E0B),
          secondary: Color(0xFFFBBF24),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF1A1A2E),
          outline: Color(0xFFE0E0F0),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5FA),
        cardTheme: const CardThemeData(
          color: Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFE8E8F5), thickness: 1),
      ),
    );
  }

  ThemePreset _crimsonTheme() {
    return ThemePreset(
      name: 'Crimson',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFDC2626),
          secondary: Color(0xFFEF4444),
          surface: Color(0xFF1A0F0F),
          onSurface: Color(0xFFF0E0E0),
          outline: Color(0xFF2E1515),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0A0A),
        cardTheme: const CardThemeData(
          color: Color(0xFF1A0F0F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFF2E1515), thickness: 1),
      ),
    );
  }

  ThemePreset _roseGoldTheme() {
    return ThemePreset(
      name: 'Rose Gold',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFEC4899),
          secondary: Color(0xFFF472B6),
          surface: Color(0xFF1A1217),
          onSurface: Color(0xFFF0E4EC),
          outline: Color(0xFF2E1A25),
        ),
        scaffoldBackgroundColor: const Color(0xFF100C0E),
        cardTheme: const CardThemeData(
          color: Color(0xFF1A1217),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFF2E1A25), thickness: 1),
      ),
    );
  }

  ThemePreset _neonCyanTheme() {
    return ThemePreset(
      name: 'Neon Cyan',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF06B6D4),
          secondary: Color(0xFF22D3EE),
          surface: Color(0xFF0F1A1C),
          onSurface: Color(0xFFD0F0F5),
          outline: Color(0xFF102030),
        ),
        scaffoldBackgroundColor: const Color(0xFF080F10),
        cardTheme: const CardThemeData(
          color: Color(0xFF0F1A1C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFF102030), thickness: 1),
      ),
    );
  }

  ThemePreset _oledBlackTheme() {
    return ThemePreset(
      name: 'OLED Black',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE5E5E5),
          secondary: Color(0xFFAAAAAA),
          surface: Color(0xFF0A0A0A),
          onSurface: Color(0xFFE8E8E8),
          outline: Color(0xFF1A1A1A),
        ),
        scaffoldBackgroundColor: const Color(0xFF000000),
        cardTheme: const CardThemeData(
          color: Color(0xFF0A0A0A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFF1A1A1A), thickness: 1),
      ),
    );
  }

  void _loadTheme() {
    final themeIndex = _settingsBox.get('theme', defaultValue: 0);
    if (themeIndex < AppTheme.values.length) {
      _currentTheme = AppTheme.values[themeIndex];
    } else {
      _currentTheme = AppTheme.amber;
    }
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
