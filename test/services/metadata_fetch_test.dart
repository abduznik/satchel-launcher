import 'package:flutter_test/flutter_test.dart';
import 'package:satchel/services/metadata_fetch_service.dart';

void main() {
  group('MetadataFetchService.nameConfidence', () {
    test('exact match scores 1.0', () {
      expect(MetadataFetchService.nameConfidence('Dark', 'Dark'), 1.0);
    });

    test('one contains the other scores 0.9', () {
      expect(MetadataFetchService.nameConfidence('Dark', 'Dark Souls'), 0.9);
      expect(MetadataFetchService.nameConfidence('Dark Souls', 'Dark'), 0.9);
    });

    test('wrong game scores below auto-apply threshold', () {
      // Folder "Dark" (2013) must NOT match "Thief"
      final score = MetadataFetchService.nameConfidence('Dark', 'Thief');
      expect(score, lessThan(MetadataFetchService.autoApplyThreshold));
    });

    test('LEGO Batman subtitle variant is confident', () {
      final score = MetadataFetchService.nameConfidence(
        'LEGO Batman Legacy of the Dark Knight',
        'LEGO Batman: Legacy of the Dark Knight',
      );
      expect(score, greaterThanOrEqualTo(MetadataFetchService.autoApplyThreshold));
    });

    test('empty inputs score 0', () {
      expect(MetadataFetchService.nameConfidence('', 'Thief'), 0.0);
      expect(MetadataFetchService.nameConfidence('Dark', ''), 0.0);
    });

    test('case insensitive', () {
      expect(MetadataFetchService.nameConfidence('dark', 'DARK'), 1.0);
    });
  });

  group('MetadataFetchService.autoApplyThreshold', () {
    test('threshold is a high-confidence value', () {
      expect(MetadataFetchService.autoApplyThreshold, greaterThan(0.5));
    });
  });
}
