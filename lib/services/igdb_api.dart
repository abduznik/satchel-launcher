import 'package:dio/dio.dart';
import '../models/game.dart';
import '../models/api_search_result.dart';

class IgdbApi {
  static const _baseUrl = 'https://api.igdb.com/v4';
  final Dio _dio;
  String? _accessToken;

  IgdbApi({Dio? dio}) : _dio = dio ?? Dio();

  Future<bool> authenticate(String clientId, String clientSecret) async {
    try {
      final response = await _dio.post(
        'https://id.twitch.tv/oauth2/token',
        queryParameters: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'client_credentials',
        },
      );
      _accessToken = response.data['access_token'];
      return _accessToken != null;
    } catch (_) {
      return false;
    }
  }

  Future<List<ApiSearchResult>> search(String query) async {
    if (_accessToken == null) return [];

    try {
      final response = await _dio.post(
        '$_baseUrl/search',
        data: 'search "$query"; fields name, id; limit 10;',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Client-ID': '',
            'Content-Type': 'application/json',
          },
        ),
      );

      final data = response.data as List? ?? [];
      return data.map((item) => ApiSearchResult(
        id: item['id'].toString(),
        name: item['name'],
        source: 'igdb',
      )).toList();
    } catch (_) {
      return [];
    }
  }

  Future<GameMetadata?> getGameDetails(String gameId) async {
    if (_accessToken == null) return null;

    try {
      final response = await _dio.post(
        '$_baseUrl/games',
        data: 'where id = $gameId; fields name, summary, genres, release_dates, involved_companies, rating;',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Client-ID': '',
            'Content-Type': 'application/json',
          },
        ),
      );

      final data = response.data as List? ?? [];
      if (data.isEmpty) return null;

      final game = data.first;
      return GameMetadata(
        summary: game['summary'],
        genres: (game['genres'] as List?)?.cast<String>() ?? [],
        releaseDate: game['release_dates']?.first?.toString(),
        rating: game['rating']?.toDouble(),
        igdbId: gameId,
      );
    } catch (_) {
      return null;
    }
  }
}
