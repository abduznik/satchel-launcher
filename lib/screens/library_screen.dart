import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_library_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/ui_provider.dart';
import '../core/input/gamepad_service.dart';
import '../widgets/game_grid.dart';
import '../widgets/focus_effect_wrapper.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _setupInputHandling();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _setupInputHandling() {
    gamepadService.actionStream.listen((action) {
      if (!mounted) return;

      switch (action) {
        case GameAction.start:
          Navigator.of(context).pushNamed('/settings');
          break;
        case GameAction.back:
          // Could show exit dialog or do nothing
          break;
        default:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gamesAsync = ref.watch(gameLibraryProvider);
    final theme = ref.watch(themeProvider);
    final ui = ref.watch(uiProvider);

    return Scaffold(
      body: Listener(
        onPointerHover: (_) => ui.setMouseMode(),
        child: KeyboardListener(
          focusNode: _focusNode,
          onKeyEvent: (event) {
            if (event is KeyDownEvent) {
              ui.setKeyboardMode();

              // Global keyboard shortcuts
              if (event.logicalKey == LogicalKeyboardKey.f5) {
                ref.read(gameLibraryProvider.notifier).rescan();
              } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.of(context).pushNamed('/settings');
              }
            }
          },
          child: Column(
            children: [
              // App Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: theme.theme.colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: theme.theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Logo
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.theme.colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.gamepad_rounded,
                        color: theme.theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Title
                    Text(
                      'Project Indie',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.theme.colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    // Game count
                    if (gamesAsync.valueOrNull != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${gamesAsync.valueOrNull!.length} games',
                          style: TextStyle(
                            color: theme.theme.colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(width: 16),
                    // Rescan button
                    FocusEffectWrapper(
                      onTap: () {
                        ref.read(gameLibraryProvider.notifier).rescan();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.refresh,
                          color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Settings button
                    FocusEffectWrapper(
                      onTap: () {
                        Navigator.of(context).pushNamed('/settings');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.settings,
                          color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: gamesAsync.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: theme.theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading games',
                          style: TextStyle(
                            color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: TextStyle(
                            color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FocusEffectWrapper(
                          onTap: () {
                            ref.read(gameLibraryProvider.notifier).rescan();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: theme.theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Retry',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  data: (games) {
                    if (games.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 80,
                              color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No games found',
                              style: TextStyle(
                                fontSize: 20,
                                color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add game folders to H:\\Games\\',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                            const SizedBox(height: 24),
                            FocusEffectWrapper(
                              onTap: () {
                                ref.read(gameLibraryProvider.notifier).rescan();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Scan Again',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return GameGrid(games: games);
                  },
                ),
              ),

              // Controller hints bar
              if (ui.inputMode == InputMode.gamepad)
                ControllerHintsBar(inputMode: ui.inputMode),
            ],
          ),
        ),
      ),
    );
  }
}
