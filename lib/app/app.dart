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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // App is closing — force exit to release all file handles (icudtl.dat, etc.)
      // This prevents the app from ghosting and locking files.
      print('[Satchel] App detached — forcing exit');
      exit(0);
    }
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
