import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:satchel/services/pcgamingwiki_service.dart';

class MockDio extends Mock implements Dio {}

class MockResponse extends Mock implements Response {}

void main() {
  group('PcgamingwikiService search candidates', () {
    late MockDio mockDio;
    late PcgamingwikiService service;

    setUp(() {
      mockDio = MockDio();
      service = PcgamingwikiService(dio: mockDio);
    });

    // --- Mocked unit tests ---

    test('LEGO Batman: exact name with colon matches', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((invocation) async {
        final params = invocation.namedArguments[#queryParameters] as Map<String, dynamic>;
        final search = params['search'] as String;
        if (search == 'LEGO Batman: Legacy of the Dark Knight') {
          return Response(data: [
            ['Lego Batman: Legacy of the Dark Knight'],
            ['Lego Batman: Legacy of the Dark Knight'],
            ['url1'], ['url2'],
          ], statusCode: 200, requestOptions: RequestOptions(path: ''));
        }
        return Response(data: [['test'], [], [], []], statusCode: 200, requestOptions: RequestOptions(path: ''));
      });

      final results = await service.searchWithConfidence('LEGO Batman: Legacy of the Dark Knight');
      expect(results, isNotEmpty);
      expect(results.first.title, 'Lego Batman: Legacy of the Dark Knight');
    });

    test('LEGO Batman without colon: inserts colon and matches', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((invocation) async {
        final params = invocation.namedArguments[#queryParameters] as Map<String, dynamic>;
        final search = params['search'] as String;
        // Should try inserting colon: "LEGO Batman: Legacy of the Dark Knight"
        if (search == 'LEGO Batman: Legacy of the Dark Knight') {
          return Response(data: [
            ['Lego Batman: Legacy of the Dark Knight'],
            ['Lego Batman: Legacy of the Dark Knight'],
            ['url1'], ['url2'],
          ], statusCode: 200, requestOptions: RequestOptions(path: ''));
        }
        return Response(data: [['test'], [], [], []], statusCode: 200, requestOptions: RequestOptions(path: ''));
      });

      final results = await service.searchWithConfidence('LEGO Batman Legacy of the Dark Knight');
      expect(results, isNotEmpty);
      expect(results.first.title, 'Lego Batman: Legacy of the Dark Knight');
    });

    test('Danganronpa without colon: inserts colon and matches', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((invocation) async {
        final params = invocation.namedArguments[#queryParameters] as Map<String, dynamic>;
        final search = params['search'] as String;
        if (search == 'Danganronpa: Trigger Happy Havoc') {
          return Response(data: [
            ['Danganronpa: Trigger Happy Havoc'],
            ['Danganronpa: Trigger Happy Havoc'],
            ['url1'], ['url2'],
          ], statusCode: 200, requestOptions: RequestOptions(path: ''));
        }
        return Response(data: [['test'], [], [], []], statusCode: 200, requestOptions: RequestOptions(path: ''));
      });

      final results = await service.searchWithConfidence('Danganronpa Trigger Happy Havoc');
      expect(results, isNotEmpty);
      expect(results.first.title, 'Danganronpa: Trigger Happy Havoc');
    });

    test('confidence scoring: exact match = 1.0', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(data: [
            ['Test Game'],
            ['Test Game'],
            ['url1'], ['url2'],
          ], statusCode: 200, requestOptions: RequestOptions(path: '')));

      final results = await service.searchWithConfidence('Test Game');
      expect(results, isNotEmpty);
      expect(results.first.score, 1.0);
    });

    test('confidence scoring: partial match has lower score', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(data: [
            ['Test Game Extended Edition'],
            ['Test Game Extended Edition'],
            ['url1'], ['url2'],
          ], statusCode: 200, requestOptions: RequestOptions(path: '')));

      final results = await service.searchWithConfidence('Test Game');
      expect(results, isNotEmpty);
      expect(results.first.score, lessThan(1.0));
      expect(results.first.score, greaterThan(0.5));
    });

    test('no results returns empty list', () async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(data: [
            ['test'],
            [],
            [],
            [],
          ], statusCode: 200, requestOptions: RequestOptions(path: '')));

      final results = await service.searchWithConfidence('NonExistentGame12345');
      expect(results, isEmpty);
    });

    // --- Live integration tests ---

    test('live: LEGO Batman without colon', () async {
      final service = PcgamingwikiService();
      final results = await service.searchWithConfidence('LEGO Batman Legacy of the Dark Knight');
      print('LEGO Batman results:');
      for (final r in results) {
        print('  ${r.title} (${(r.score * 100).toStringAsFixed(0)}%)');
      }
      expect(results, isNotEmpty);
      expect(results.first.title, contains('Batman'));
    });

    test('live: Danganronpa without colon', () async {
      final service = PcgamingwikiService();
      final results = await service.searchWithConfidence('Danganronpa Trigger Happy Havoc');
      print('Danganronpa results:');
      for (final r in results) {
        print('  ${r.title} (${(r.score * 100).toStringAsFixed(0)}%)');
      }
      expect(results, isNotEmpty);
      expect(results.first.title, contains('Danganronpa'));
    });

    test('live: Hollow Knight (no special chars)', () async {
      final service = PcgamingwikiService();
      final results = await service.searchWithConfidence('Hollow Knight');
      print('Hollow Knight results:');
      for (final r in results) {
        print('  ${r.title} (${(r.score * 100).toStringAsFixed(0)}%)');
      }
      expect(results, isNotEmpty);
    });
  });
}
