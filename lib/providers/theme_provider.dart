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
      case AppTheme.defaultDark: return _defaultDarkTheme();
      case AppTheme.light:       return _lightTheme();
      case AppTheme.crimson:     return _crimsonTheme();
      case AppTheme.roseGold:    return _roseGoldTheme();
      case AppTheme.neonCyan:    return _neonCyanTheme();
      case AppTheme.oledBlack:   return _oledBlackTheme();
    }
  }

  ThemePreset _defaultDarkTheme() {
    const bg    = Color(0xFF0E0E16);
    const surf  = Color(0xFF161622);
    const acc   = Color(0xFF7C3AED);
    return ThemePreset(
      name: 'Default Dark',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: acc,
          secondary: const Color(0xFF9F67FF),
          surface: surf,
          onSurface: const Color(0xFFE2E2F0),
          outline: const Color(0xFF2E2E45),
        ),
        scaffoldBackgroundColor: bg,
        cardTheme: CardThemeData(
          color: surf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        appBarTheme: const AppBarTheme(backgroundColor: surf, elevation: 0),
        dividerTheme: const DividerThemeData(color: Color(0xFF2E2E45), thickness: 1),
      ),
    );
  }

  ThemePreset _lightTheme() {
    const bg   = Color(0xFFF5F5FA);
    const surf = Color(0xFFFFFFFF);
    const acc  = Color(0xFF7C3AED);
    return ThemePreset(
      name: 'Light',
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: acc,
          secondary: const Color(0xFF9F67FF),
          surface: surf,
          onSurface: const Color(0xFF1A1A2E),
          outline: const Color(0xFFE0E0F0),
        ),
        scaffoldBackgroundColor: bg,
        cardTheme: CardThemeData(
          color: surf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFE8E8F5), thickness: 1),
      ),
    );
  }

  ThemePreset _crimsonTheme() {
    const bg   = Color(0xFF0F0A0A);
    const surf = Color(0xFF1A0F0F);
    const acc  = Color(0xFFDC2626);
    return ThemePreset(
      name: 'Crimson',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: acc,
          secondary: const Color(0xFFEF4444),
          surface: surf,
          onSurface: const Color(0xFFF0E0E0),
          outline: const Color(0xFF2E1515),
        ),
        scaffoldBackgroundColor: bg,
        cardTheme: CardThemeData(
          color: surf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFF2E1515), thickness: 1),
      ),
    );
  }

  ThemePreset _roseGoldTheme() {
    const bg   = Color(0xFF100C0E);
    const surf = Color(0xFF1A1217);
    const acc  = Color(0xFFEC4899);
    return ThemePreset(
      name: 'Rose Gold',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: acc,
          secondary: const Color(0xFFF472B6),
          surface: surf,
          onSurface: const Color(0xFFF0E4EC),
          outline: const Color(0xFF2E1A25),
        ),
        scaffoldBackgroundColor: bg,
        cardTheme: CardThemeData(
          color: surf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFF2E1A25), thickness: 1),
      ),
    );
  }

  ThemePreset _neonCyanTheme() {
    const bg   = Color(0xFF080F10);
    const surf = Color(0xFF0F1A1C);
    const acc  = Color(0xFF06B6D4);
    return ThemePreset(
      name: 'Neon Cyan',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: acc,
          secondary: const Color(0xFF22D3EE),
          surface: surf,
          onSurface: const Color(0xFFD0F0F5),
          outline: const Color(0xFF102030),
        ),
        scaffoldBackgroundColor: bg,
        cardTheme: CardThemeData(
          color: surf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFF102030), thickness: 1),
      ),
    );
  }

  ThemePreset _oledBlackTheme() {
    const bg   = Color(0xFF000000);
    const surf = Color(0xFF0A0A0A);
    const acc  = Color(0xFFE5E5E5);
    return ThemePreset(
      name: 'OLED Black',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: acc,
          secondary: const Color(0xFFAAAAAA),
          surface: surf,
          onSurface: const Color(0xFFE8E8E8),
          outline: const Color(0xFF1A1A1A),
        ),
        scaffoldBackgroundColor: bg,
        cardTheme: CardThemeData(
          color: surf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFF1A1A1A), thickness: 1),
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
