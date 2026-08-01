import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game.dart';

/// Tracks the currently running game and its process.
/// Any widget in the app can read this to show "Now Playing" state.
class PlayingGame {
  final Game game;
  final Process process;
  final DateTime startedAt;

  PlayingGame({
    required this.game,
    required this.process,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();
}

/// Global state for the currently playing game.
/// Null when no game is running.
final playingGameProvider = StateProvider<PlayingGame?>((ref) => null);

/// Whether a specific game is currently running.
bool isGamePlaying(WidgetRef ref, String gameId) {
  final playing = ref.read(playingGameProvider);
  return playing != null && playing.game.id == gameId;
}

/// Whether any game is running.
bool isAnyGamePlaying(WidgetRef ref) {
  return ref.read(playingGameProvider) != null;
}

/// Gracefully stops the currently running game.
/// Kills the process tree to ensure the game and all child processes are terminated.
Future<void> stopCurrentGame(WidgetRef ref) async {
  final playing = ref.read(playingGameProvider);
  if (playing == null) return;

  final pid = playing.process.pid;
  print('[PlayingGame] Stopping game: ${playing.game.name} (PID: $pid)');

  try {
    if (Platform.isWindows) {
      // taskkill /T kills the process tree (all child processes)
      await Process.run('taskkill', ['/F', '/T', '/PID', '$pid']);
    } else {
      // On macOS/Linux (Wine): kill the process group
      await Process.run('kill', ['-TERM', '$pid']);
      // Give it a moment to exit gracefully
      await Future.delayed(const Duration(seconds: 2));
      // Force kill if still running
      try {
        await Process.run('kill', ['-9', '$pid']);
      } catch (_) {}
    }
    print('[PlayingGame] Game stopped');
  } catch (e) {
    print('[PlayingGame] Error stopping game: $e');
  }

  ref.read(playingGameProvider.notifier).state = null;
}
