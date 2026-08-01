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
        '/FI',
        'IMAGENAME eq $exeName',
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
      updateStatus(
          LaunchStatus.error, '${currentPlaying.game.name} is already running');
      return;
    }

    try {
      // Step 1: Check OmniSave config
      updateStatus(LaunchStatus.checking, 'Checking save configuration...');
      final metaFile = File(p.join(game.folderPath, '.indie', 'meta.json'));
      bool omnisaveConfigured = false;
      if (await metaFile.exists()) {
        try {
          final meta =
              jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
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
      final omniSave =
          OmniSaveService(savesBasePath: settings.resolvedSavesPath);
      final gameExeName = p.basename(game.exePath);

      // Try OmniSave first
      final omniSaveProcess = await omniSave.launchGame(
        game,
        localSavePath: existingLocalPath,
      );

      if (omniSaveProcess != null) {
        // Poll for the actual game process — it may take a while to spawn.
        int? gamePid;
        for (var i = 0; i < 15 && gamePid == null; i++) {
          gamePid = await _findGameProcess(gameExeName);
          if (gamePid == null) {
            await Future.delayed(const Duration(seconds: 1));
          }
        }

        if (gamePid != null) {
          updateStatus(LaunchStatus.running, 'Running');

          _startTracking(
            ref: ref,
            game: game,
            pid: gamePid,
            processName: gameExeName,
            onStatusChanged: updateStatus,
            onExitWork: () => omniSave.cleanupAfterLaunch(game),
          );
        } else {
          // Game exe not found yet — attach to OmniSave. When OmniSave exits
          // after launching the game, the tracker immediately re-detects the
          // game process by name so it doesn't falsely report the game as
          // stopped (and doesn't wait for the 2s polling cycle).
          print(
              '[GameLaunch] game.exe not found, tracking by name for re-detection');
          updateStatus(LaunchStatus.running, 'Running via OmniSave');

          _startTracking(
            ref: ref,
            game: game,
            pid: omniSaveProcess.pid,
            processName: gameExeName,
            process: omniSaveProcess,
            onStatusChanged: updateStatus,
            onExitWork: () => omniSave.cleanupAfterLaunch(game),
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

      updateStatus(LaunchStatus.running, 'Running');

      _startTracking(
        ref: ref,
        game: game,
        pid: gameProcess.pid,
        processName: gameExeName,
        process: gameProcess,
        onStatusChanged: updateStatus,
      );
    } catch (e) {
      print('[GameLaunch] Error: $e');
      updateStatus(LaunchStatus.error, 'Launch failed: $e');
      ref.read(playingGameProvider.notifier).state = null;
    }
  }

  /// Sets up a [ProcessTracker], stores the playing game in the provider,
  /// and updates last-played. Kept in one place so all launch paths behave
  /// identically and the tracker always knows the process name.
  ///
  /// When [process] is provided (a process we started ourselves), the tracker
  /// listens to its [Process.exitCode] directly for instant exit detection
  /// instead of waiting for the 2s polling cycle.
  void _startTracking({
    required WidgetRef ref,
    required Game game,
    required int pid,
    required String processName,
    required void Function(LaunchStatus, String) onStatusChanged,
    Process? process,
    Future<void> Function()? onExitWork,
  }) {
    final tracker = ProcessTracker(
      onExit: () async {
        print('[GameLaunch] Process exited ($processName)');
        try {
          if (onExitWork != null) {
            onStatusChanged(LaunchStatus.syncing, 'Syncing saves...');
            await onExitWork();
          }
          onStatusChanged(LaunchStatus.done, '');
        } catch (e) {
          print('[GameLaunch] Error during exit cleanup: $e');
        } finally {
          // ALWAYS clear the playing state so the UI reverts to PLAY.
          ref.read(playingGameProvider.notifier).state = null;
        }
      },
    );
    if (process != null) {
      tracker.attach(process, name: processName);
    } else {
      tracker.attachByName(pid, processName);
    }

    ref.read(playingGameProvider.notifier).state = PlayingGame(
      game: game,
      pid: pid,
      processName: processName,
      tracker: tracker,
    );
    ref.read(gameLibraryProvider.notifier).updateGame(
          game.copyWith(lastPlayed: DateTime.now()),
        );
  }
}
