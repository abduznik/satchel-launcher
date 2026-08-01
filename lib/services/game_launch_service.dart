import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../models/game.dart';
import '../providers/game_library_provider.dart';
import '../providers/playing_game_provider.dart';
import '../providers/settings_provider.dart';
import 'omnisave_service.dart';
import 'process_tracker.dart';
import 'windows_launch_service.dart';

/// Status of a game launch operation.
enum LaunchStatus {
  idle,
  checking,
  launching,
  running,
  syncing,
  done,
  error,
}

/// Centralized game launch orchestrator.
class GameLaunchService {
  /// Finds the actual game.exe process after OmniSave launches it.
  Future<int?> _findGameProcess(String exeName) async {
    try {
      final result = await Process.run('tasklist', [
        '/FI', 'IMAGENAME eq $exeName',
        '/NH',
      ]);
      final output = result.stdout.toString();
      if (output.contains(exeName) && !output.contains('INFO:')) {
        final lines = output.split('\n');
        for (final line in lines) {
          if (line.toLowerCase().contains(exeName.toLowerCase())) {
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.length >= 2) {
              final pid = int.tryParse(parts[1]);
              if (pid != null) {
                print('[GameLaunch] Found $exeName with PID: $pid');
                return pid;
              }
            }
          }
        }
      }
    } catch (e) {
      print('[GameLaunch] Error finding process: $e');
    }
    return null;
  }

  /// Launches a game with full lifecycle management.
  Future<void> launch(
    Game game,
    WidgetRef ref, {
    required void Function(LaunchStatus, String) onStatusChanged,
  }) async {
    void updateStatus(LaunchStatus status, String message) {
      onStatusChanged(status, message);
      print('[GameLaunch] ${status.name}: $message');
    }

    // Guard: check if a game is already running
    final currentPlaying = ref.read(playingGameProvider);
    if (currentPlaying != null) {
      updateStatus(LaunchStatus.error, '${currentPlaying.game.name} is already running');
      return;
    }

    try {
      // Step 1: Check OmniSave config
      updateStatus(LaunchStatus.checking, 'Checking save configuration...');
      final metaFile = File(p.join(game.folderPath, '.indie', 'meta.json'));
      bool omnisaveConfigured = false;
      if (await metaFile.exists()) {
        try {
          final meta = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
          omnisaveConfigured = meta['omnisaveConfigured'] == true;
        } catch (_) {}
      }

      if (!omnisaveConfigured) {
        updateStatus(LaunchStatus.idle, '');
        return;
      }

      // Step 2: Launch the game
      updateStatus(LaunchStatus.launching, 'Starting ${game.name}...');

      final iniFile = File(p.join(game.folderPath, '.indie', 'omnisave.ini'));
      String? existingLocalPath;
      if (await iniFile.exists()) {
        try {
          for (final line in await iniFile.readAsLines()) {
            if (line.startsWith('Local_Path=')) {
              existingLocalPath = line.substring('Local_Path='.length).trim();
              break;
            }
          }
        } catch (_) {}
      }

      final settings = ref.read(settingsProvider);
      final omniSave = OmniSaveService(savesBasePath: settings.resolvedSavesPath);

      // Try OmniSave first
      final omniSaveProcess = await omniSave.launchGame(
        game,
        localSavePath: existingLocalPath,
      );

      if (omniSaveProcess != null) {
        final gameExeName = p.basename(game.exePath);
        await Future.delayed(const Duration(seconds: 2));
        final gamePid = await _findGameProcess(gameExeName);

        if (gamePid != null) {
          updateStatus(LaunchStatus.running, 'Running');

          // Create tracker and store it IN the provider so it survives navigation
          final tracker = ProcessTracker(
            onExit: () async {
              print('[GameLaunch] Game exited');
              updateStatus(LaunchStatus.syncing, 'Syncing saves...');
              await omniSave.cleanupAfterLaunch(game);
              updateStatus(LaunchStatus.done, '');
              ref.read(playingGameProvider.notifier).state = null;
            },
          );
          tracker.attachByName(gamePid, gameExeName);

          ref.read(playingGameProvider.notifier).state = PlayingGame(
            game: game,
            pid: gamePid,
            processName: gameExeName,
            tracker: tracker,
          );
          ref.read(gameLibraryProvider.notifier).updateGame(
            game.copyWith(lastPlayed: DateTime.now()),
          );
        } else {
          print('[GameLaunch] game.exe not found, tracking OmniSave as fallback');
          updateStatus(LaunchStatus.running, 'Running via OmniSave');

          final tracker = ProcessTracker(
            onExit: () async {
              print('[GameLaunch] OmniSave exited');
              updateStatus(LaunchStatus.syncing, 'Syncing saves...');
              await omniSave.cleanupAfterLaunch(game);
              updateStatus(LaunchStatus.done, '');
              ref.read(playingGameProvider.notifier).state = null;
            },
          );
          tracker.attach(omniSaveProcess);

          ref.read(playingGameProvider.notifier).state = PlayingGame(
            game: game,
            pid: omniSaveProcess.pid,
            processName: 'OmniSave.exe',
            tracker: tracker,
          );
          ref.read(gameLibraryProvider.notifier).updateGame(
            game.copyWith(lastPlayed: DateTime.now()),
          );
        }
        return;
      }

      // Step 3: Direct launch (no OmniSave)
      final gameProcess = await WindowsLaunchService.launch(game.exePath);

      if (gameProcess == null) {
        updateStatus(LaunchStatus.error, 'Failed to launch ${game.name}');
        return;
      }

      final gameExeName = p.basename(game.exePath);
      updateStatus(LaunchStatus.running, 'Running');

      final tracker = ProcessTracker(
        onExit: () {
          print('[GameLaunch] Game exited');
          updateStatus(LaunchStatus.done, '');
          ref.read(playingGameProvider.notifier).state = null;
        },
      );
      tracker.attach(gameProcess);

      ref.read(playingGameProvider.notifier).state = PlayingGame(
        game: game,
        pid: gameProcess.pid,
        processName: gameExeName,
        tracker: tracker,
      );
      ref.read(gameLibraryProvider.notifier).updateGame(
        game.copyWith(lastPlayed: DateTime.now()),
      );
    } catch (e) {
      print('[GameLaunch] Error: $e');
      updateStatus(LaunchStatus.error, 'Launch failed: $e');
      ref.read(playingGameProvider.notifier).state = null;
    }
  }
}
