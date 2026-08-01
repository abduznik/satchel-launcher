import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:satchel/services/steamgriddb_api.dart';
import 'package:satchel/services/igdb_api.dart';
import 'package:satchel/services/screenscraper_api.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    registerFallbackValue(Options());
  });

  group('API Key Validation Regression', () {
    group('SteamGridDB', () {
      test('accepts valid key format', () async {
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
        expect(await api.validate('abc123'), true);
      });

      test('rejects empty key', () async {
        final api = SteamGridDbApi(dio: mockDio);
        expect(await api.validate(''), false);
      });

      test('rejects 401 response', () async {
        when(() => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenThrow(DioException(
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 401,
            requestOptions: RequestOptions(path: ''),
          ),
          requestOptions: RequestOptions(path: ''),
        ));

        final api = SteamGridDbApi(dio: mockDio);
        expect(await api.validate('key'), false);
      });

      test('rejects 403 response', () async {
        when(() => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenThrow(DioException(
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 403,
            requestOptions: RequestOptions(path: ''),
          ),
          requestOptions: RequestOptions(path: ''),
        ));

        final api = SteamGridDbApi(dio: mockDio);
        expect(await api.validate('key'), false);
      });

      test('handles connection timeout', () async {
        when(() => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenThrow(DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(path: ''),
        ));

        final api = SteamGridDbApi(dio: mockDio);
        expect(await api.validate('key'), false);
      });
    });

    group('IGDB', () {
      test('accepts valid credentials', () async {
        when(() => mockDio.post(
          any(),
          queryParameters: any(named: 'queryParameters'),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          data: {'access_token': 'token', 'expires_in': 3600},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final api = IgdbApi(dio: mockDio);
        expect(await api.validate('id', 'secret'), true);
      });

      test('rejects empty client ID', () async {
        final api = IgdbApi(dio: mockDio);
        expect(await api.validate('', 'secret'), false);
      });

      test('rejects empty client secret', () async {
        final api = IgdbApi(dio: mockDio);
        expect(await api.validate('id', ''), false);
      });

      test('rejects invalid credentials (401)', () async {
        when(() => mockDio.post(
          any(),
          queryParameters: any(named: 'queryParameters'),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenThrow(DioException(
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 401,
            requestOptions: RequestOptions(path: ''),
          ),
          requestOptions: RequestOptions(path: ''),
        ));

        final api = IgdbApi(dio: mockDio);
        expect(await api.validate('bad', 'creds'), false);
      });

      test('handles network failure gracefully', () async {
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
        expect(await api.validate('id', 'secret'), false);
      });

      test('validates before authenticate is called', () async {
        final api = IgdbApi(dio: mockDio);
        expect(api.isAuthenticated, false);
        // validate should still work independently
        when(() => mockDio.post(
          any(),
          queryParameters: any(named: 'queryParameters'),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          data: {'access_token': 'token'},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));
        expect(await api.validate('id', 'secret'), true);
        // but isAuthenticated should still be false (validate doesn't set state)
        expect(api.isAuthenticated, false);
      });
    });

    group('ScreenScraper', () {
      test('accepts valid credentials', () async {
        when(() => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => Response(
          data: {'response': {'jeux': []}},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final api = ScreenScraperApi(dio: mockDio);
        expect(await api.validate('user', 'pass'), true);
      });

      test('rejects empty username', () async {
        final api = ScreenScraperApi(dio: mockDio);
        expect(await api.validate('', 'pass'), false);
      });

      test('rejects empty password', () async {
        final api = ScreenScraperApi(dio: mockDio);
        expect(await api.validate('user', ''), false);
      });

      test('rejects invalid credentials', () async {
        when(() => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenThrow(DioException(
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 401,
            requestOptions: RequestOptions(path: ''),
          ),
          requestOptions: RequestOptions(path: ''),
        ));

        final api = ScreenScraperApi(dio: mockDio);
        expect(await api.validate('bad', 'creds'), false);
      });

      test('handles server error gracefully', () async {
        when(() => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenThrow(DioException(
          type: DioExceptionType.badResponse,
          response: Response(
            statusCode: 500,
            requestOptions: RequestOptions(path: ''),
          ),
          requestOptions: RequestOptions(path: ''),
        ));

        final api = ScreenScraperApi(dio: mockDio);
        expect(await api.validate('user', 'pass'), false);
      });
    });

    group('search after validation', () {
      test('SteamGridDB search works after key set', () async {
        when(() => mockDio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          data: {
            'data': [
              {'id': 1, 'name': 'Half-Life 3'},
            ],
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final api = SteamGridDbApi(dio: mockDio);
        api.setApiKey('valid-key');
        final results = await api.search('Half-Life');
        expect(results, isNotEmpty);
        expect(results.first.name, 'Half-Life 3');
        expect(results.first.source, 'steamgriddb');
      });

      test('IGDB search returns empty when not authenticated', () async {
        final api = IgdbApi(dio: mockDio);
        // Search requires authentication, returns empty when not authenticated
        final results = await api.search('test');
        expect(results, isEmpty);
      });
    });
  });
}
