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


class ProjectIndieApp extends ConsumerStatefulWidget {
  const ProjectIndieApp({super.key});

  @override
  ConsumerState<ProjectIndieApp> createState() => _ProjectIndieAppState();
}

class _ProjectIndieAppState extends ConsumerState<ProjectIndieApp> {
  @override
  void initState() {
    super.initState();
    gamepadService.startPolling();
  }

  @override
  void dispose() {
    gamepadService.dispose();
    super.dispose();
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
          title: 'Project Indie',
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
