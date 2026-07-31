import 'package:dio/dio.dart';
import '../models/api_search_result.dart';

class ScreenScraperApi {
  static const _baseUrl = 'https://www.screenscraper.fr/api';
  final Dio _dio;
  String? _username;
  String? _password;

  ScreenScraperApi({Dio? dio}) : _dio = dio ?? Dio();

  void setCredentials(String username, String password) {
    _username = username;
    _password = password;
  }

  Map<String, dynamic> _getAuthParams() {
    final params = <String, dynamic>{
      'output': 'json',
    };
    if (_username != null && _password != null) {
      params['devid'] = _username;
      params['devpassword'] = _password;
    }
    return params;
  }

  Future<List<ApiSearchResult>> search(String query) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/jeuRecherche.php',
        queryParameters: {
          ..._getAuthParams(),
          'recherche': query,
        },
      );

      final data = response.data['response']?['jeux'] as List? ?? [];
      return data.map((item) => ApiSearchResult(
        id: item['id'].toString(),
        name: item['nom'],
        source: 'screenscraper',
      )).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> getCoverUrl(String gameId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/jeu.php',
        queryParameters: {
          ..._getAuthParams(),
          'jeuid': gameId,
          'media': 'boxart',
        },
      );

      final media = response.data['response']?['jeu']?['medias'] as List? ?? [];
      final boxart = media.firstWhere(
        (m) => m['type'] == 'boxart',
        orElse: () => null,
      );

      return boxart?['url'];
    } catch (_) {
      return null;
    }
  }
}
