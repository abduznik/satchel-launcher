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
  ProcessTracker? _tracker;

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

      // Read existing Local_Path from ini
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
      final omniSave = OmniSaveService(savesBasePath: settings.savesPath);

      // Try OmniSave first
      final omniSaveProcess = await omniSave.launchGame(
        game,
        localSavePath: existingLocalPath,
      );

      if (omniSaveProcess != null) {
        updateStatus(LaunchStatus.running, 'Running via OmniSave');

        ref.read(playingGameProvider.notifier).state = PlayingGame(
          game: game,
          process: omniSaveProcess,
        );

        ref.read(gameLibraryProvider.notifier).updateGame(
          game.copyWith(lastPlayed: DateTime.now()),
        );

        _tracker = ProcessTracker(
          onExit: () async {
            print('[GameLaunch] OmniSave exited');
            updateStatus(LaunchStatus.syncing, 'Syncing saves...');
            await omniSave.cleanupAfterLaunch(game);
            updateStatus(LaunchStatus.done, '');
            ref.read(playingGameProvider.notifier).state = null;
          },
        );
        _tracker!.attach(omniSaveProcess);
        return;
      }

      // Step 3: Direct launch (no OmniSave)
      final gameProcess = await WindowsLaunchService.launch(game.exePath);

      if (gameProcess == null) {
        updateStatus(LaunchStatus.error, 'Failed to launch ${game.name}');
        return;
      }

      updateStatus(LaunchStatus.running, 'Running');

      ref.read(playingGameProvider.notifier).state = PlayingGame(
        game: game,
        process: gameProcess,
      );

      ref.read(gameLibraryProvider.notifier).updateGame(
        game.copyWith(lastPlayed: DateTime.now()),
      );

      _tracker = ProcessTracker(
        onExit: () {
          print('[GameLaunch] Game exited');
          updateStatus(LaunchStatus.done, '');
          ref.read(playingGameProvider.notifier).state = null;
        },
      );
      _tracker!.attach(gameProcess);
    } catch (e) {
      print('[GameLaunch] Error: $e');
      updateStatus(LaunchStatus.error, 'Launch failed: $e');
      ref.read(playingGameProvider.notifier).state = null;
    }
  }

  void cancel() {
    _tracker?.dispose();
    _tracker = null;
  }
}
