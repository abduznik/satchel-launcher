import 'package:dio/dio.dart';
import '../models/api_search_result.dart';

class SteamGridDbApi {
  static const _baseUrl = 'https://www.steamgriddb.com/api/v2';
  final Dio _dio;
  String? _apiKey;

  SteamGridDbApi({Dio? dio}) : _dio = dio ?? Dio();

  void setApiKey(String key) {
    _apiKey = key;
  }

  Future<List<ApiSearchResult>> search(String query) async {
    if (_apiKey == null || _apiKey!.isEmpty) return [];

    try {
      final response = await _dio.get(
        '$_baseUrl/search/games/term/$query',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
          },
        ),
      );

      final data = response.data['data'] as List? ?? [];
      return data.map((item) => ApiSearchResult(
        id: item['id'].toString(),
        name: item['name'],
        source: 'steamgriddb',
      )).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> getCoverUrl(String gameId) async {
    if (_apiKey == null || _apiKey!.isEmpty) return null;

    try {
      final response = await _dio.get(
        '$_baseUrl/grids/game/$gameId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
          },
        ),
      );

      final data = response.data['data'] as List? ?? [];
      if (data.isNotEmpty) {
        return data.first['thumb'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
