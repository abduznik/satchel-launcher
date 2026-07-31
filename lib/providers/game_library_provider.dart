import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/game.dart';
import '../services/game_scanner.dart';

final gameScannerProvider = Provider<GameScanner>((ref) {
  return GameScanner(gamesPath: 'H:\\Games');
});

final gameLibraryProvider =
    StateNotifierProvider<GameLibraryNotifier, AsyncValue<List<Game>>>((ref) {
  return GameLibraryNotifier(ref);
});

class GameLibraryNotifier extends StateNotifier<AsyncValue<List<Game>>> {
  final Ref _ref;
  late final GameScanner _scanner;
  late final Box _gamesBox;

  GameLibraryNotifier(this._ref) : super(const AsyncValue.loading()) {
    _scanner = _ref.read(gameScannerProvider);
    _gamesBox = Hive.box('games');
    _loadGames();
  }

  Future<void> _loadGames() async {
    state = const AsyncValue.loading();
    try {
      // Load cached games from Hive
      final cached = _gamesBox.get('games', defaultValue: []);
      final games = (cached as List)
          .map((g) => Game.fromJson(Map<String, dynamic>.from(g)))
          .toList();
      state = AsyncValue.data(games);

      // Also scan for new games
      await rescan();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> rescan() async {
    try {
      final scannedGames = await _scanner.scan();
      state = AsyncValue.data(scannedGames);

      // Cache to Hive
      final jsonList = scannedGames.map((g) => g.toJson()).toList();
      await _gamesBox.put('games', jsonList);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateGame(Game updatedGame) async {
    final currentGames = state.valueOrNull ?? [];
    final index = currentGames.indexWhere((g) => g.id == updatedGame.id);
    if (index == -1) return;

    final newGames = [...currentGames];
    newGames[index] = updatedGame;
    state = AsyncValue.data(newGames);

    // Save to Hive
    final jsonList = newGames.map((g) => g.toJson()).toList();
    await _gamesBox.put('games', jsonList);
  }

  Future<void> removeGame(String gameId) async {
    final currentGames = state.valueOrNull ?? [];
    final newGames = currentGames.where((g) => g.id != gameId).toList();
    state = AsyncValue.data(newGames);

    // Save to Hive
    final jsonList = newGames.map((g) => g.toJson()).toList();
    await _gamesBox.put('games', jsonList);
  }
}
