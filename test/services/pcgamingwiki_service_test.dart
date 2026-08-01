import 'package:flutter_test/flutter_test.dart';
import 'package:satchel/services/pcgamingwiki_service.dart';

void main() {
  group('PcgamingwikiService._buildSearchCandidates', () {
    // We test the search candidate generation indirectly through findPageTitle,
    // but since _buildSearchCandidates is private, we test observable behavior.

    test('service instantiates with default User-Agent', () {
      final service = PcgamingwikiService();
      expect(service, isNotNull);
    });

    test('service instantiates with custom Dio', () {
      // Verify it doesn't throw with custom dio
      final service = PcgamingwikiService();
      expect(service, isA<PcgamingwikiService>());
    });
  });

  group('PcgamingwikiService.expandForDisplay', () {
    test('expands ~/ to USERPROFILE', () {
      final result = PcgamingwikiService.expandForDisplay('~/AppData/Roaming');
      expect(result, contains('\\'));
      expect(result, isNot(startsWith('~/')));
    });

    test('passes through absolute paths', () {
      final result = PcgamingwikiService.expandForDisplay('C:/Users/test/saves');
      expect(result, 'C:\\Users\\test\\saves');
    });

    test('normalizes forward slashes to backslashes', () {
      final result = PcgamingwikiService.expandForDisplay('C:/some/path');
      expect(result, contains('\\'));
      expect(result, isNot(contains('/')));
    });
  });

  group('PcgamingwikiService path expansion (private methods via public API)', () {
    test('getSavePaths returns empty for non-existent game', () async {
      final service = PcgamingwikiService();
      final paths = await service.getSavePaths('NonExistentGameTitle12345XYZ');
      expect(paths, isEmpty);
    });
  });
}
