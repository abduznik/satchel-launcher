import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_config.dart';
import '../services/steamgriddb_api.dart';
import '../services/igdb_api.dart';
import '../services/screenscraper_api.dart';
import '../services/encryption_service.dart';

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
    try {
      final encrypted = await _ref.read(encryptionServiceProvider).loadEncrypted();
      state = ApiConfig.fromJson(encrypted.map((k, v) => MapEntry(k, v)));
    } catch (_) {
      state = ApiConfig();
    }
  }

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
    final data = state.toJson();
    final stringData = data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    await _ref.read(encryptionServiceProvider).saveEncrypted(stringData);
  }
}

final steamGridDbProvider = Provider<SteamGridDbApi>((ref) {
  final config = ref.watch(apiConfigProvider);
  final api = SteamGridDbApi();
  if (config.steamGridDbKey != null) {
    api.setApiKey(config.steamGridDbKey!);
  }
  return api;
});

final igdbProvider = Provider<IgdbApi>((ref) {
  final config = ref.watch(apiConfigProvider);
  final api = IgdbApi();
  if (config.igdbClientId != null && config.igdbClientSecret != null) {
    api.authenticate(config.igdbClientId!, config.igdbClientSecret!);
  }
  return api;
});

final screenScraperProvider = Provider<ScreenScraperApi>((ref) {
  final config = ref.watch(apiConfigProvider);
  final api = ScreenScraperApi();
  if (config.screenScraperUsername != null && config.screenScraperPassword != null) {
    api.setCredentials(config.screenScraperUsername!, config.screenScraperPassword!);
  }
  return api;
});
