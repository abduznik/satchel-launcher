import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../providers/ui_provider.dart';
import '../core/input/gamepad_service.dart';
import '../screens/splash_screen.dart';
import '../screens/library_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/setup_wizard_screen.dart';

class SatchelApp extends ConsumerStatefulWidget {
  const SatchelApp({super.key});

  @override
  ConsumerState<SatchelApp> createState() => _SatchelAppState();
}

class _SatchelAppState extends ConsumerState<SatchelApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gamepadServiceProvider);
    });
    // Kill orphaned processes from previous sessions
    _killOrphanedProcesses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// When the app is closing, kill any tracked game/OmniSave processes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      print('[Satchel] App detaching — cleaning up processes');
      _killOrphanedProcesses();
    }
  }

  void _killOrphanedProcesses() {
    try {
      if (Platform.isWindows) {
        Process.run('taskkill', ['/F', '/IM', 'OmniSave.exe']);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final ui = ref.watch(uiProvider);

    return Listener(
      onPointerHover: (_) => ui.setMouseMode(),
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent || event is KeyRepeatEvent) {
            ui.setKeyboardMode();
          }
        },
        child: MaterialApp(
          title: 'Satchel',
          debugShowCheckedModeBanner: false,
          theme: theme.theme,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/setup': (context) => const SetupWizardScreen(),
            '/library': (context) => const LibraryScreen(),
            '/settings': (context) => const SettingsScreen(),
          },
        ),
      ),
    );
  }
}
