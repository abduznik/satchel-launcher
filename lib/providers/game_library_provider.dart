import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import '../models/game.dart';
import '../services/game_scanner.dart';
import 'settings_provider.dart';
import 'api_provider.dart';

final gameScannerProvider = Provider<GameScanner>((ref) {
  final settings = ref.watch(settingsProvider);
  final path = settings.resolvedGamesPath;
  print('[gameScannerProvider] Scanner path from settings: $path');
  return GameScanner(gamesPath: path);
});

final gameLibraryProvider =
    StateNotifierProvider<GameLibraryNotifier, AsyncValue<List<Game>>>((ref) {
  return GameLibraryNotifier(ref);
});

class GameLibraryNotifier extends StateNotifier<AsyncValue<List<Game>>> {
  final Ref _ref;
  late final Box _gamesBox;

  GameLibraryNotifier(this._ref) : super(const AsyncValue.loading()) {
    _gamesBox = Hive.box('games');
    print('[GameLibraryNotifier] Initialized');
    _loadGames();
  }

  GameScanner get _scanner => _ref.read(gameScannerProvider);

  Future<void> _loadGames() async {
    print('[GameLibraryNotifier] Loading games from cache...');
    state = const AsyncValue.loading();
    try {
      final cached = _gamesBox.get('games', defaultValue: []);
      final rawGames = (cached as List)
          .map((g) => Game.fromStorageJson(_deepCast(g)))
          .toList();

      // Validate file paths — clear any that no longer exist on disk
      // (e.g. drive letter changed, game moved). Prevents showing gray placeholders.
      final games = await Future.wait(rawGames.map((game) async {
        String? cover = game.coverPath;
        String? banner = game.bannerPath;
        if (cover != null && !await File(cover).exists()) {
          print('[GameLibraryNotifier] Stale coverPath cleared for ${game.name}: $cover');
          cover = null;
        }
        if (banner != null && !await File(banner).exists()) {
          banner = null;
        }
        if (cover != game.coverPath || banner != game.bannerPath) {
          return game.copyWith(coverPath: cover, bannerPath: banner);
        }
        return game;
      }));

      print('[GameLibraryNotifier] Loaded ${games.length} cached games');
      state = AsyncValue.data(games);
      // Do NOT call rescan() here — splash screen triggers it after setup check.
    } catch (e, st) {
      print('[GameLibraryNotifier] Error loading: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> rescan() async {
    final path = _scanner.gamesPath;
    print('[GameLibraryNotifier] Rescanning $path...');
    if (path.isEmpty) {
      print('[GameLibraryNotifier] No games path configured');
      state = const AsyncValue.data([]);
      return;
    }
    try {
      final scannedGames = await _scanner.scan();
      print('[GameLibraryNotifier] Found ${scannedGames.length} games');
      state = AsyncValue.data(scannedGames);

      final jsonList = scannedGames.map((g) => g.toStorageJson()).toList();
      await _gamesBox.put('games', jsonList);

      // Kick off artwork fetching in the background — does not block rescan.
      Future.delayed(Duration.zero).then((_) => _fetchMissingArtwork(scannedGames));
    } catch (e, st) {
      print('[GameLibraryNotifier] Error scanning: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _fetchMissingArtwork(List<Game> games) async {
    print('[ArtworkFetch] Checking ${games.length} games for missing metadata');

    // Wait up to 5s for API config to load
    for (var i = 0; i < 50; i++) {
      final config = _ref.read(apiConfigProvider);
      if (config.igdbEnabled || config.steamGridDbEnabled || config.screenScraperEnabled) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Wait for IGDB auth token if IGDB is enabled
    final config = _ref.read(apiConfigProvider);
    if (config.igdbEnabled) {
      final igdb = _ref.read(igdbProvider);
      for (var i = 0; i < 30; i++) {
        if (igdb.isAuthenticated) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    final fetchService = _ref.read(metadataFetchServiceProvider);

    for (final game in games) {
      if (!mounted) return;

      // Skip if game already has cover AND banner on disk — fully fetched
      final coverFile = File(p.join(game.folderPath, '.indie', 'cover.jpg'));
      final bannerFile = File(p.join(game.folderPath, '.indie', 'banner.jpg'));
      final hasCover = game.coverPath != null || await coverFile.exists();

      if (hasCover) {
        // Wire up path if missing
        if (game.coverPath == null && await coverFile.exists()) {
          await updateGame(game.copyWith(coverPath: coverFile.path));
        }
        if (game.bannerPath == null && await bannerFile.exists()) {
          await updateGame(game.copyWith(bannerPath: bannerFile.path));
        }
        print('[ArtworkFetch] ${game.name} — already has cover, skipping');
        continue;
      }

      // No cover — fetch full metadata
      print('[ArtworkFetch] Fetching full metadata for ${game.name}...');
      try {
        final candidates = await fetchService.searchCandidates(game.name);
        if (!mounted) return;

        if (candidates.isNotEmpty) {
          final best = candidates.first;
          final data = await fetchService.fetchFull(game, best);
          if (!mounted) return;

          final updated = game.copyWith(
            coverPath: data.coverPath,
            bannerPath: data.bannerPath,
            metadata: data.metadata,
          );
          await updateGame(updated);
          print('[ArtworkFetch] ✓ Full metadata saved for ${game.name}');
        } else {
          print('[ArtworkFetch] ✗ No results for ${game.name}');
        }
      } catch (e) {
        print('[ArtworkFetch] ✗ Error fetching ${game.name}: $e');
      }

      // Respect API rate limits
      await Future.delayed(const Duration(milliseconds: 800));
    }
  }

  Future<void> updateGame(Game updatedGame) async {
    final currentGames = state.valueOrNull ?? [];
    final index = currentGames.indexWhere((g) => g.id == updatedGame.id);
    if (index == -1) return;

    final newGames = [...currentGames];
    newGames[index] = updatedGame;
    state = AsyncValue.data(newGames);

    final jsonList = newGames.map((g) => g.toStorageJson()).toList();
    await _gamesBox.put('games', jsonList);
  }

  /// Recursively casts a Hive-returned map to Map<String, dynamic>.
  static Map<String, dynamic> _deepCast(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    return map.map((k, v) {
      if (v is Map) return MapEntry(k, _deepCast(v));
      if (v is List) return MapEntry(k, v.map((e) => e is Map ? _deepCast(e) : e).toList());
      return MapEntry(k, v);
    });
  }

  Future<void> removeGame(String gameId) async {
    final currentGames = state.valueOrNull ?? [];
    final newGames = currentGames.where((g) => g.id != gameId).toList();
    state = AsyncValue.data(newGames);

    final jsonList = newGames.map((g) => g.toStorageJson()).toList();
    await _gamesBox.put('games', jsonList);
  }
}
