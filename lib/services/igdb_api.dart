import 'package:dio/dio.dart';
import '../models/game.dart';
import '../models/api_search_result.dart';

class IgdbApi {
  static const _baseUrl = 'https://api.igdb.com/v4';
  final Dio _dio;
  String? _accessToken;
  String? _clientId;

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
      _clientId = clientId;
      return _accessToken != null;
    } catch (_) {
      return false;
    }
  }

  /// Validates credentials by attempting to authenticate with Twitch.
  /// Returns true if the credentials are valid, false otherwise.
  Future<bool> validate(String clientId, String clientSecret) async {
    try {
      final response = await _dio.post(
        'https://id.twitch.tv/oauth2/token',
        queryParameters: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'client_credentials',
        },
      );
      return response.statusCode == 200 &&
          response.data['access_token'] != null;
    } catch (_) {
      return false;
    }
  }

  bool get isAuthenticated => _accessToken != null && _clientId != null;

  Options get _headers => Options(
    headers: {
      'Authorization': 'Bearer $_accessToken',
      'Client-ID': _clientId ?? '',
    },
  );

  // ---------------------------------------------------------------------------
  // Search — returns lightweight results for the picker UI (name + cover thumb)
  // ---------------------------------------------------------------------------
  Future<List<ApiSearchResult>> search(String query) async {
    if (!isAuthenticated) return [];

    try {
      final response = await _dio.post(
        '$_baseUrl/games',
        data: 'search "${query.replaceAll('"', '')}"; '
            'fields name,id,cover.url,first_release_date; '
            'limit 15;',
        options: _headers,
      );

      final data = response.data as List? ?? [];
      return data.map((item) {
        String? coverUrl = item['cover']?['url'] as String?;
        if (coverUrl != null) {
          coverUrl = _thumbUrl(coverUrl, 't_cover_big');
        }
        String? year;
        final epoch = item['first_release_date'];
        if (epoch != null) {
          year = DateTime.fromMillisecondsSinceEpoch((epoch as int) * 1000)
              .year
              .toString();
        }
        return ApiSearchResult(
          id: item['id'].toString(),
          name: item['name'] as String? ?? '',
          source: 'igdb',
          thumbnailUrl: coverUrl,
          year: year,
        );
      }).toList();
    } catch (e) {
      print('[IgdbApi] search error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Full details — called after user selects a result in the picker
  // Returns metadata + raw image URLs (caller downloads them)
  // ---------------------------------------------------------------------------
  Future<IgdbFullDetails?> getFullDetails(String gameId) async {
    if (!isAuthenticated) return null;

    try {
      final response = await _dio.post(
        '$_baseUrl/games',
        data: 'where id = $gameId; '
            'fields name,summary,genres.name,'
            'first_release_date,'
            'involved_companies.company.name,'
            'involved_companies.developer,'
            'involved_companies.publisher,'
            'rating,rating_count,'
            'cover.url,'
            'artworks.url,'
            'screenshots.url,'
            'videos.name,videos.video_id;',
        options: _headers,
      );

      final data = response.data as List? ?? [];
      if (data.isEmpty) return null;

      final g = data.first as Map<String, dynamic>;

      final genres = (g['genres'] as List?)
              ?.map((x) => x['name'] as String? ?? '')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [];

      String? developer;
      String? publisher;
      for (final c in (g['involved_companies'] as List? ?? [])) {
        final name = c['company']?['name'] as String?;
        if (name == null) continue;
        if (c['developer'] == true) developer ??= name;
        if (c['publisher'] == true) publisher ??= name;
      }

      DateTime? releaseDate;
      final epoch = g['first_release_date'];
      if (epoch != null) {
        releaseDate =
            DateTime.fromMillisecondsSinceEpoch((epoch as int) * 1000);
      }

      String? coverUrl = g['cover']?['url'] as String?;
      if (coverUrl != null) coverUrl = _thumbUrl(coverUrl, 't_cover_big');

      // Hero/banner: prefer artworks, fall back to first screenshot
      final artworkUrls = (g['artworks'] as List? ?? [])
          .map((a) => _thumbUrl(a['url'] as String? ?? '', 't_1080p'))
          .where((u) => u.isNotEmpty)
          .toList();

      final screenshotUrls = (g['screenshots'] as List? ?? [])
          .map((s) => _thumbUrl(s['url'] as String? ?? '', 't_screenshot_big'))
          .where((u) => u.isNotEmpty)
          .toList();

      // Banner: first artwork (landscape), else first screenshot
      String? bannerUrl;
      if (artworkUrls.isNotEmpty) {
        bannerUrl = artworkUrls.first;
      } else if (screenshotUrls.isNotEmpty) {
        bannerUrl = screenshotUrls.first;
      }

      final videos = (g['videos'] as List? ?? [])
          .map((v) => IgdbVideo(
                name: v['name'] as String? ?? '',
                videoId: v['video_id'] as String? ?? '',
              ))
          .where((v) => v.videoId.isNotEmpty)
          .toList();

      final metadata = GameMetadata(
        summary: g['summary'] as String?,
        genres: genres,
        releaseDate: releaseDate?.year.toString(),
        developer: developer,
        publisher: publisher,
        rating: (g['rating'] as num?)?.toDouble(),
        ratingCount: (g['rating_count'] as num?)?.toInt(),
        videos: videos,
        igdbId: gameId,
      );

      return IgdbFullDetails(
        metadata: metadata,
        coverUrl: coverUrl,
        bannerUrl: bannerUrl,
        screenshotUrls: screenshotUrls,
      );
    } catch (e) {
      print('[IgdbApi] getFullDetails error: $e');
      return null;
    }
  }

  // kept for backward-compat with MetadataFetchService background scan
  Future<GameMetadata?> getGameDetails(String gameId) async {
    final d = await getFullDetails(gameId);
    return d?.metadata;
  }

  Future<String?> getCoverUrl(String gameId) async {
    if (!isAuthenticated) return null;
    try {
      final response = await _dio.post(
        '$_baseUrl/games',
        data: 'where id = $gameId; fields cover.url;',
        options: _headers,
      );
      final data = response.data as List? ?? [];
      if (data.isEmpty) return null;
      String? url = data.first['cover']?['url'] as String?;
      if (url != null) url = _thumbUrl(url, 't_cover_big');
      return url;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  static String _thumbUrl(String raw, String size) {
    if (raw.isEmpty) return '';
    var url = raw;
    if (url.startsWith('//')) url = 'https:$url';
    // Replace any existing size token
    return url.replaceAll(RegExp(r't_[a-z0-9_]+'), size);
  }
}

// Returned by getFullDetails — holds raw URLs before downloading
class IgdbFullDetails {
  final GameMetadata metadata;
  final String? coverUrl;
  final String? bannerUrl;
  final List<String> screenshotUrls;

  IgdbFullDetails({
    required this.metadata,
    this.coverUrl,
    this.bannerUrl,
    this.screenshotUrls = const [],
  });
}
