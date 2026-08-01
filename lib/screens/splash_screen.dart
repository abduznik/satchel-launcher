import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../providers/game_library_provider.dart';
import '../services/drive_service.dart';
import '../services/migration_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _barController;

  late Animation<double> _fadeIn;
  late Animation<double> _pulse;
  late Animation<double> _barProgress;

  @override
  void initState() {
    super.initState();
    print('[SplashScreen] InitState');
    print('[SplashScreen] appDir: ${DriveService.appDir}');
    print('[SplashScreen] configPath: ${DriveService.configPath}');

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat(reverse: true);

    _barController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _barProgress = CurvedAnimation(parent: _barController, curve: Curves.easeInOut);

    _fadeController.forward();
    _barController.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Minimum splash display so the animation has time to show
    final settingsBox = Hive.box('settings');
    final setupDone = settingsBox.get('setupDone', defaultValue: false);
    print('[SplashScreen] setupDone = $setupDone');

    if (!setupDone) {
      // Check if there's existing data on the drive that could be migrated
      final migrationInfo = await MigrationService.scan();
      if (!mounted) return;

      if (migrationInfo.hasAnyData) {
        // Found existing data — show migration dialog before setup
        final shouldMigrate = await _showMigrationDialog(migrationInfo);
        if (!mounted) return;

        if (shouldMigrate) {
          final result = await MigrationService.migrate();
          if (!mounted) return;

          if (result.success && result.settingsImported) {
            // Migration successful — go straight to library
            final hasCached = Hive.box('games').get('games', defaultValue: []) as List;
            if (hasCached.isNotEmpty) {
              Navigator.of(context).pushReplacementNamed('/library');
              ref.read(gameLibraryProvider.notifier).rescan();
              return;
            }
          }
        }
      }

      // No data to migrate or user declined — go to setup
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/setup');
    } else {
      // Navigate to library immediately showing cached games,
      // then kick off a background rescan (non-blocking).
      // If no cache exists yet, wait for one quick scan first.
      final hasCached = Hive.box('games').get('games', defaultValue: [])
          as List;

      if (hasCached.isNotEmpty) {
        // Show library immediately with cached data, rescan in background
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/library');
        // Background rescan — does not block navigation
        ref.read(gameLibraryProvider.notifier).rescan();
      } else {
        // First run after setup — do one scan before showing library
        await ref.read(gameLibraryProvider.notifier).rescan();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/library');
      }
    }
  }

  Future<bool> _showMigrationDialog(MigrationInfo info) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.find_in_page_rounded, color: Color(0xFF7C3AED), size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Existing Data Found')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We found existing data on this drive:',
              style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                info.describe(),
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Would you like to import this data? Your API keys, '
              'settings, and game metadata will be restored. '
              'Game files themselves will not be copied.',
              style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5), height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Start Fresh', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import Data'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _barController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0A0A10);
    const accentColor = Color(0xFF7C3AED);

    return Scaffold(
      backgroundColor: bgColor,
      body: FadeTransition(
        opacity: _fadeIn,
        child: Stack(
          children: [
            // Subtle radial gradient background
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      accentColor.withValues(alpha: 0.08),
                      bgColor,
                    ],
                  ),
                ),
              ),
            ),

            // Center content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated gem / logo shape
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.15 + 0.25 * _pulse.value),
                              blurRadius: 40 + 30 * _pulse.value,
                              spreadRadius: 4 + 8 * _pulse.value,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF9F67FF), Color(0xFF5B21B6)],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.diamond_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Title with gradient text
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFD8C4FF), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Text(
                      'PROJECT INDIE',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 8,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'PORTABLE GAME LAUNCHER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.35),
                      letterSpacing: 4,
                    ),
                  ),

                  const SizedBox(height: 64),

                  // Thin animated progress bar
                  SizedBox(
                    width: 220,
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _barProgress,
                          builder: (context, _) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: _barProgress.value,
                                minHeight: 2,
                                backgroundColor: Colors.white.withValues(alpha: 0.08),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF9F67FF),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Loading...',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.25),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Version tag bottom-right
            Positioned(
              bottom: 20,
              right: 24,
              child: Text(
                'v1.0',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.15),
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
