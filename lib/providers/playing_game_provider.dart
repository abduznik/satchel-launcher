import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game.dart';

/// Tracks the currently running game.
class PlayingGame {
  final Game game;
  final int pid;
  final String processName; // e.g. "game.exe" or "OmniSave.exe"
  final DateTime startedAt;

  PlayingGame({
    required this.game,
    required this.pid,
    required this.processName,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();
}

/// Global state for the currently playing game.
final playingGameProvider = StateProvider<PlayingGame?>((ref) => null);

bool isAnyGamePlaying(WidgetRef ref) {
  return ref.read(playingGameProvider) != null;
}

/// Stops the currently running game by killing the process tree.
Future<void> stopCurrentGame(WidgetRef ref) async {
  final playing = ref.read(playingGameProvider);
  if (playing == null) return;

  final pid = playing.pid;
  final name = playing.processName;
  print('[PlayingGame] Stopping: ${playing.game.name} (PID: $pid, name: $name)');

  try {
    if (Platform.isWindows) {
      // Kill by PID
      await Process.run('taskkill', ['/F', '/T', '/PID', '$pid']);
      // Also kill by name in case PID changed
      await Process.run('taskkill', ['/F', '/IM', name]);
    } else {
      await Process.run('kill', ['-TERM', '$pid']);
      await Future.delayed(const Duration(seconds: 2));
      try {
        await Process.run('kill', ['-9', '$pid']);
      } catch (_) {}
      // Also kill by name
      try {
        await Process.run('pkill', ['-f', name]);
      } catch (_) {}
    }
    print('[PlayingGame] Stopped');
  } catch (e) {
    print('[PlayingGame] Error stopping: $e');
  }

  ref.read(playingGameProvider.notifier).state = null;
}
