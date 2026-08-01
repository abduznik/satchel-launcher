import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:project_indie/services/steamgriddb_api.dart';
import 'package:project_indie/services/igdb_api.dart';
import 'package:project_indie/services/screenscraper_api.dart';

class MockDio extends Mock implements Dio {}

class MockResponse extends Mock implements Response {}

void main() {
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
  });

  setUpAll(() {
    registerFallbackValue(Options());
  });

  group('SteamGridDbApi', () {
    test('validate returns true for valid key', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      )).thenAnswer((_) async => Response(
        data: {'data': []},
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ));

      final api = SteamGridDbApi(dio: mockDio);
      final result = await api.validate('valid-key');
      expect(result, true);
    });

    test('validate returns false for invalid key (401)', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      )).thenThrow(DioException(
        type: DioExceptionType.badResponse,
        response: Response(
          data: {'message': 'Unauthorized'},
          statusCode: 401,
          requestOptions: RequestOptions(path: ''),
        ),
        requestOptions: RequestOptions(path: ''),
      ));

      final api = SteamGridDbApi(dio: mockDio);
      final result = await api.validate('bad-key');
      expect(result, false);
    });

    test('validate returns false on network error', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      )).thenThrow(DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(path: ''),
      ));

      final api = SteamGridDbApi(dio: mockDio);
      final result = await api.validate('key');
      expect(result, false);
    });

    test('search returns empty when no API key set', () async {
      final api = SteamGridDbApi(dio: mockDio);
      final results = await api.search('test');
      expect(results, isEmpty);
    });

    test('search returns results for valid query', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      )).thenAnswer((_) async => Response(
        data: {
          'data': [
            {'id': 1, 'name': 'Test Game'},
          ],
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ));

      final api = SteamGridDbApi(dio: mockDio);
      api.setApiKey('valid-key');
      final results = await api.search('test');
      expect(results.length, 1);
      expect(results.first.name, 'Test Game');
      expect(results.first.source, 'steamgriddb');
    });

    test('getCoverUrl returns null when no API key', () async {
      final api = SteamGridDbApi(dio: mockDio);
      final url = await api.getCoverUrl('123');
      expect(url, isNull);
    });
  });

  group('IgdbApi', () {
    test('validate returns true for valid credentials', () async {
      when(() => mockDio.post(
        any(),
        queryParameters: any(named: 'queryParameters'),
        data: any(named: 'data'),
        options: any(named: 'options'),
      )).thenAnswer((_) async => Response(
        data: {'access_token': 'test-token'},
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ));

      final api = IgdbApi(dio: mockDio);
      final result = await api.validate('client-id', 'client-secret');
      expect(result, true);
    });

    test('validate returns false for invalid credentials', () async {
      when(() => mockDio.post(
        any(),
        queryParameters: any(named: 'queryParameters'),
        data: any(named: 'data'),
        options: any(named: 'options'),
      )).thenThrow(DioException(
        type: DioExceptionType.badResponse,
        response: Response(
          data: {'message': 'Unauthorized'},
          statusCode: 401,
          requestOptions: RequestOptions(path: ''),
        ),
        requestOptions: RequestOptions(path: ''),
      ));

      final api = IgdbApi(dio: mockDio);
      final result = await api.validate('bad', 'creds');
      expect(result, false);
    });

    test('validate returns false on network error', () async {
      when(() => mockDio.post(
        any(),
        queryParameters: any(named: 'queryParameters'),
        data: any(named: 'data'),
        options: any(named: 'options'),
      )).thenThrow(DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(path: ''),
      ));

      final api = IgdbApi(dio: mockDio);
      final result = await api.validate('id', 'secret');
      expect(result, false);
    });

    test('isAuthenticated is false when not authenticated', () {
      final api = IgdbApi(dio: mockDio);
      expect(api.isAuthenticated, false);
    });

    test('search returns empty when not authenticated', () async {
      final api = IgdbApi(dio: mockDio);
      final results = await api.search('test');
      expect(results, isEmpty);
    });
  });

  group('ScreenScraperApi', () {
    test('validate returns true for valid credentials', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenAnswer((_) async => Response(
        data: {'response': {'jeux': []}},
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ));

      final api = ScreenScraperApi(dio: mockDio);
      final result = await api.validate('user', 'pass');
      expect(result, true);
    });

    test('validate returns false for invalid credentials', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenThrow(DioException(
        type: DioExceptionType.badResponse,
        response: Response(
          data: {'error': 'Unauthorized'},
          statusCode: 401,
          requestOptions: RequestOptions(path: ''),
        ),
        requestOptions: RequestOptions(path: ''),
      ));

      final api = ScreenScraperApi(dio: mockDio);
      final result = await api.validate('bad', 'creds');
      expect(result, false);
    });

    test('validate returns false on network error', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenThrow(DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(path: ''),
      ));

      final api = ScreenScraperApi(dio: mockDio);
      final result = await api.validate('user', 'pass');
      expect(result, false);
    });

    test('search returns empty when no credentials', () async {
      final api = ScreenScraperApi(dio: mockDio);
      final results = await api.search('test');
      expect(results, isEmpty);
    });

    test('search returns results with credentials', () async {
      when(() => mockDio.get(
        any(),
        queryParameters: any(named: 'queryParameters'),
      )).thenAnswer((_) async => Response(
        data: {
          'response': {
            'jeux': [
              {'id': 1, 'nom': 'Test Game'},
            ],
          },
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ));

      final api = ScreenScraperApi(dio: mockDio);
      api.setCredentials('user', 'pass');
      final results = await api.search('test');
      expect(results.length, 1);
      expect(results.first.name, 'Test Game');
      expect(results.first.source, 'screenscraper');
    });
  });
}
