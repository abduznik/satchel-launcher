import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import '../models/game.dart';
import '../services/game_scanner.dart';
import '../services/metadata_fetch_service.dart';
import 'activity_provider.dart';
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
          print(
              '[GameLibraryNotifier] Stale coverPath cleared for ${game.name}: $cover');
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

    final activity = _ref.read(activityProvider.notifier);
    activity.show('Scanning for games...', detail: path);

    // Snapshot existing game ids before the scan so we can detect new games.
    final previousIds = (state.valueOrNull ?? []).map((g) => g.id).toSet();

    try {
      final scannedGames = await _scanner.scan(
        onProgress: (current, total, folderName) {
          activity.update('Scanning $current/$total...', detail: folderName);
        },
      );
      print('[GameLibraryNotifier] Found ${scannedGames.length} games');
      state = AsyncValue.data(scannedGames);

      final newGames =
          scannedGames.where((g) => !previousIds.contains(g.id)).toList();
      if (newGames.isNotEmpty) {
        print(
            '[GameLibraryNotifier] New games: ${newGames.map((g) => g.name).join(', ')}');
        activity.update(
          'Scanning complete',
          detail:
              '${newGames.length} new game${newGames.length == 1 ? '' : 's'} found',
        );
      } else {
        activity.update('Scanning complete',
            detail: '${scannedGames.length} games');
      }

      final jsonList = scannedGames.map((g) => g.toStorageJson()).toList();
      await _gamesBox.put('games', jsonList);
      activity.success();

      // Kick off artwork fetching in the background — does not block rescan.
      Future.delayed(Duration.zero)
          .then((_) => _fetchMissingArtwork(scannedGames));
    } catch (e, st) {
      print('[GameLibraryNotifier] Error scanning: $e');
      activity.error();
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _fetchMissingArtwork(List<Game> games) async {
    print('[ArtworkFetch] Checking ${games.length} games for missing metadata');
    final activity = _ref.read(activityProvider.notifier);
    activity.show('Checking metadata...', detail: '0/${games.length}');

    // Wait up to 5s for API config to load
    for (var i = 0; i < 50; i++) {
      final config = _ref.read(apiConfigProvider);
      if (config.igdbEnabled ||
          config.steamGridDbEnabled ||
          config.screenScraperEnabled) {
        break;
      }
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
    var checked = 0;

    for (final game in games) {
      if (!mounted) return;

      checked++;
      activity.update('Checking metadata...',
          detail: '$checked/${games.length} · ${game.name}');

      // Skip games already fully scanned before (persisted via meta.json /
      // Hive). The autoScanned flag means the auto-fetch already ran for this
      // game, regardless of whether it found anything — so we never hammer the
      // API on every launch for games that legitimately have no metadata
      // (e.g. "Dark" (2013)).
      if (game.metadata?.autoScanned == true) {
        print('[ArtworkFetch] ${game.name} — already scanned, skipping');
        continue;
      }

      // Check if metadata is COMPLETE
      final coverFile = File(p.join(game.folderPath, '.indie', 'cover.jpg'));
      final bannerFile = File(p.join(game.folderPath, '.indie', 'banner.jpg'));
      final hasCover = game.coverPath != null || await coverFile.exists();
      final hasMetadata =
          game.metadata?.summary != null && game.metadata!.genres.isNotEmpty;

      if (hasMetadata) {
        // Metadata is complete — just wire up paths if missing
        if (!hasCover && await coverFile.exists()) {
          await updateGame(game.copyWith(coverPath: coverFile.path));
        }
        if (game.bannerPath == null && await bannerFile.exists()) {
          await updateGame(game.copyWith(bannerPath: bannerFile.path));
        }
        // Mark as auto-scanned so we don't re-check next launch.
        await _markAutoScanned(game);
        print('[ArtworkFetch] ${game.name} — metadata complete, skipping');
        continue;
      }

      // Incomplete — fetch full metadata
      print(
          '[ArtworkFetch] Fetching full metadata for ${game.name} (cover=$hasCover, meta=$hasMetadata)...');
      try {
        final candidates = await fetchService.searchCandidates(game.name);
        if (!mounted) return;

        if (candidates.isNotEmpty) {
          // Only auto-apply a candidate if it confidently matches the folder
          // name. Otherwise we'd overwrite manual metadata with a wrong game
          // (e.g. folder "Dark" → IGDB "Thief").
          final best = candidates.first;
          final confidence = MetadataFetchService.nameConfidence(game.name, best.name);
          if (confidence < MetadataFetchService.autoApplyThreshold) {
            print(
                '[ArtworkFetch] ✗ "${game.name}" vs "${best.name}" too weak ($confidence), skipping');
            await _markAutoScanned(game);
            continue;
          }

          // Clear old assets if cover exists but metadata is incomplete
          final data = await fetchService.fetchFull(game, best,
              clearOld: hasCover && !hasMetadata);
          if (!mounted) return;

          final updated = game.copyWith(
            coverPath: data.coverPath ?? game.coverPath,
            bannerPath: data.bannerPath ?? game.bannerPath,
            metadata: data.metadata?.copyWith(autoScanned: true),
          );
          await updateGame(updated);
          // Persist to .indie/meta.json so the fetched metadata survives a
          // rescan — otherwise every launch re-fetches it from the API.
          await _saveMetadataToDisk(updated);
          print('[ArtworkFetch] ✓ Full metadata saved for ${game.name}');
        } else {
          print('[ArtworkFetch] ✗ No results for ${game.name}');
          // No results — still mark as scanned so we don't retry every launch.
          await _markAutoScanned(game);
        }
      } catch (e) {
        print('[ArtworkFetch] ✗ Error fetching ${game.name}: $e');
      }

      // Respect API rate limits
      await Future.delayed(const Duration(milliseconds: 800));
    }

    activity.success(detail: '$checked/${games.length} games checked');
  }

  /// Marks a game's metadata as auto-scanned (flag persisted to Hive + disk)
  /// so the background fetch never retries it on a later scan.
  Future<void> _markAutoScanned(Game game) async {
    final meta = game.metadata;
    if (meta != null && meta.autoScanned) return;

    final updated = game.copyWith(
      metadata: (meta ?? GameMetadata()).copyWith(autoScanned: true),
    );
    await updateGame(updated);
    await _saveMetadataToDisk(updated);
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

  /// Writes the game's metadata + art paths to .indie/meta.json so it survives
  /// a rescan. The scanner reads meta.json from disk on every launch — without
  /// this, auto-fetched metadata is only in the Hive cache and gets re-fetched
  /// from the API on every scan (e.g. Dinoblade) instead of skipping instantly.
  Future<void> _saveMetadataToDisk(Game game) async {
    if (game.metadata == null) return;
    try {
      final indieDir = Directory(p.join(game.folderPath, '.indie'));
      if (!await indieDir.exists()) {
        await indieDir.create(recursive: true);
      }
      final metaFile = File(p.join(indieDir.path, 'meta.json'));

      // Merge with any existing keys (e.g. omnisaveConfigured, skipSaveSync)
      Map<String, dynamic> existing = {};
      if (await metaFile.exists()) {
        try {
          existing =
              jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        } catch (_) {}
      }

      existing['coverPath'] = game.coverPath;
      existing['bannerPath'] = game.bannerPath;
      existing.addAll(game.metadata!.toJson());

      await metaFile.writeAsString(jsonEncode(existing));
      print('[GameLibraryNotifier] meta.json written for ${game.name}');
    } catch (e) {
      print('[GameLibraryNotifier] Failed to write meta.json for ${game.name}: $e');
    }
  }

  /// Recursively casts a Hive-returned map to Map<String, dynamic>.
  static Map<String, dynamic> _deepCast(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    return map.map((k, v) {
      if (v is Map) {
        return MapEntry(k, _deepCast(v));
      }
      if (v is List) {
        return MapEntry(k, v.map((e) => e is Map ? _deepCast(e) : e).toList());
      }
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
