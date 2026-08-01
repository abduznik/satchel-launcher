import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_config.dart';
import '../services/steamgriddb_api.dart';
import '../services/igdb_api.dart';
import '../services/screenscraper_api.dart';
import '../services/encryption_service.dart';
import '../services/metadata_fetch_service.dart';

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

final apiConfigProvider =
    StateNotifierProvider<ApiConfigNotifier, ApiConfig>((ref) {
  return ApiConfigNotifier(ref);
});

class ApiConfigNotifier extends StateNotifier<ApiConfig> {
  final Ref _ref;

  ApiConfigNotifier(this._ref) : super(ApiConfig()) {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    print('[ApiConfigNotifier] Loading API config...');
    try {
      final encrypted = await _ref.read(encryptionServiceProvider).loadEncrypted();
      print('[ApiConfigNotifier] Loaded keys: ${encrypted.keys.toList()}');
      state = ApiConfig.fromMap(encrypted);
      print('[ApiConfigNotifier] Config: steamGridDb=${state.steamGridDbEnabled}, igdb=${state.igdbEnabled}, ss=${state.screenScraperEnabled}');
    } catch (e) {
      print('[ApiConfigNotifier] Error loading config: $e');
      state = ApiConfig();
    }
  }

  // --- Validation methods ---

  /// Validates a SteamGridDB API key by making a test request.
  Future<bool> validateSteamGridDbKey(String key) async {
    if (key.trim().isEmpty) return false;
    final api = SteamGridDbApi();
    return api.validate(key.trim());
  }

  /// Validates IGDB credentials by attempting authentication.
  Future<bool> validateIgdbCredentials(String clientId, String clientSecret) async {
    if (clientId.trim().isEmpty || clientSecret.trim().isEmpty) return false;
    final api = IgdbApi();
    return api.validate(clientId.trim(), clientSecret.trim());
  }

  /// Validates ScreenScraper credentials by making a test request.
  Future<bool> validateScreenScraperCredentials(String username, String password) async {
    if (username.trim().isEmpty || password.trim().isEmpty) return false;
    final api = ScreenScraperApi();
    return api.validate(username.trim(), password.trim());
  }

  // --- Update methods (save without validation, called after validation passes) ---

  Future<void> updateSteamGridDbKey(String? key) async {
    state = state.copyWith(
      steamGridDbKey: key,
      steamGridDbEnabled: key != null && key.isNotEmpty,
    );
    await _saveConfig();
  }

  Future<void> updateIgdbCredentials(String? clientId, String? clientSecret) async {
    state = state.copyWith(
      igdbClientId: clientId,
      igdbClientSecret: clientSecret,
      igdbEnabled: clientId != null && clientId.isNotEmpty &&
          clientSecret != null && clientSecret.isNotEmpty,
    );
    await _saveConfig();
  }

  Future<void> updateScreenScraperCredentials(String? username, String? password) async {
    state = state.copyWith(
      screenScraperUsername: username,
      screenScraperPassword: password,
      screenScraperEnabled: username != null && username.isNotEmpty &&
          password != null && password.isNotEmpty,
    );
    await _saveConfig();
  }

  Future<void> _saveConfig() async {
    final data = state.toMap();
    print('[ApiConfigNotifier] Saving config: ${data.keys.toList()}');
    await _ref.read(encryptionServiceProvider).saveEncrypted(data);
  }
}

final steamGridDbProvider = Provider<SteamGridDbApi>((ref) {
  final config = ref.watch(apiConfigProvider);
  final api = SteamGridDbApi();
  if (config.steamGridDbKey != null && config.steamGridDbKey!.isNotEmpty) {
    api.setApiKey(config.steamGridDbKey!);
  }
  return api;
});

// Cache for authenticated IGDB instances keyed by clientId+secret
final _igdbCache = <String, IgdbApi>{};

final igdbProvider = Provider<IgdbApi>((ref) {
  final config = ref.watch(apiConfigProvider);
  final clientId = config.igdbClientId ?? '';
  final clientSecret = config.igdbClientSecret ?? '';

  if (clientId.isEmpty || clientSecret.isEmpty) return IgdbApi();

  final cacheKey = '$clientId:$clientSecret';
  if (_igdbCache.containsKey(cacheKey)) return _igdbCache[cacheKey]!;

  final api = IgdbApi();
  _igdbCache[cacheKey] = api;
  // Authenticate eagerly; search() checks isAuthenticated before calling
  api.authenticate(clientId, clientSecret);
  return api;
});

final screenScraperProvider = Provider<ScreenScraperApi>((ref) {
  final config = ref.watch(apiConfigProvider);
  final api = ScreenScraperApi();
  if (config.screenScraperUsername != null && config.screenScraperPassword != null &&
      config.screenScraperUsername!.isNotEmpty && config.screenScraperPassword!.isNotEmpty) {
    api.setCredentials(config.screenScraperUsername!, config.screenScraperPassword!);
  }
  return api;
});

final metadataFetchServiceProvider = Provider<MetadataFetchService>((ref) {
  final config = ref.watch(apiConfigProvider);
  return MetadataFetchService(
    steamGridDb: config.steamGridDbEnabled ? ref.read(steamGridDbProvider) : null,
    igdb: config.igdbEnabled ? ref.read(igdbProvider) : null,
  );
});
