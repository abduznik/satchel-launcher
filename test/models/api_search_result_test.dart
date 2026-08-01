import 'package:flutter_test/flutter_test.dart';
import 'package:satchel/models/api_search_result.dart';

void main() {
  group('ApiSearchResult', () {
    test('creates with required fields', () {
      final result = ApiSearchResult(
        id: '1',
        name: 'Test Game',
        source: 'steamgriddb',
      );
      expect(result.id, '1');
      expect(result.name, 'Test Game');
      expect(result.source, 'steamgriddb');
      expect(result.thumbnailUrl, isNull);
      expect(result.year, isNull);
    });

    test('creates with all fields', () {
      final result = ApiSearchResult(
        id: '42',
        name: 'Cyber Game',
        source: 'igdb',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        year: '2024',
      );
      expect(result.id, '42');
      expect(result.name, 'Cyber Game');
      expect(result.source, 'igdb');
      expect(result.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(result.year, '2024');
    });

    test('different sources work correctly', () {
      final sgdb = ApiSearchResult(id: '1', name: 'Game', source: 'steamgriddb');
      final igdb = ApiSearchResult(id: '2', name: 'Game', source: 'igdb');
      final ss = ApiSearchResult(id: '3', name: 'Game', source: 'screenscraper');
      expect(sgdb.source, 'steamgriddb');
      expect(igdb.source, 'igdb');
      expect(ss.source, 'screenscraper');
    });

    test('empty strings are valid', () {
      final result = ApiSearchResult(id: '', name: '', source: '');
      expect(result.id, '');
      expect(result.name, '');
      expect(result.source, '');
    });
  });
}
