import 'package:flutter_test/flutter_test.dart';
import 'package:project_indie/models/api_config.dart';

void main() {
  group('ApiConfig', () {
    test('creates with all nulls and disabled by default', () {
      final config = ApiConfig();
      expect(config.steamGridDbKey, isNull);
      expect(config.igdbClientId, isNull);
      expect(config.igdbClientSecret, isNull);
      expect(config.screenScraperUsername, isNull);
      expect(config.screenScraperPassword, isNull);
      expect(config.steamGridDbEnabled, false);
      expect(config.igdbEnabled, false);
      expect(config.screenScraperEnabled, false);
    });

    test('creates with values', () {
      final config = ApiConfig(
        steamGridDbKey: 'key123',
        igdbClientId: 'client',
        igdbClientSecret: 'secret',
        screenScraperUsername: 'user',
        screenScraperPassword: 'pass',
        steamGridDbEnabled: true,
        igdbEnabled: true,
        screenScraperEnabled: true,
      );
      expect(config.steamGridDbKey, 'key123');
      expect(config.steamGridDbEnabled, true);
      expect(config.igdbEnabled, true);
      expect(config.screenScraperEnabled, true);
    });

    group('fromMap', () {
      test('parses valid map', () {
        final map = {
          'steamGridDbKey': 'sgdb-key',
          'igdbClientId': 'igdb-cid',
          'igdbClientSecret': 'igdb-cs',
          'screenScraperUsername': 'ss-user',
          'screenScraperPassword': 'ss-pass',
          'steamGridDbEnabled': 'true',
          'igdbEnabled': 'true',
          'screenScraperEnabled': 'false',
        };
        final config = ApiConfig.fromMap(map);
        expect(config.steamGridDbKey, 'sgdb-key');
        expect(config.igdbClientId, 'igdb-cid');
        expect(config.igdbClientSecret, 'igdb-cs');
        expect(config.screenScraperUsername, 'ss-user');
        expect(config.screenScraperPassword, 'ss-pass');
        expect(config.steamGridDbEnabled, true);
        expect(config.igdbEnabled, true);
        expect(config.screenScraperEnabled, false);
      });

      test('treats null/empty/"null" as absent', () {
        final map = <String, String>{
          'steamGridDbKey': '',
          'igdbClientId': 'null',
          'screenScraperUsername': 'user',
        };
        final config = ApiConfig.fromMap(map);
        expect(config.steamGridDbKey, isNull);
        expect(config.igdbClientId, isNull);
        expect(config.screenScraperUsername, 'user');
      });

      test('parses bool strings case-insensitively', () {
        final map = {
          'steamGridDbEnabled': 'TRUE',
          'igdbEnabled': 'False',
        };
        final config = ApiConfig.fromMap(map);
        expect(config.steamGridDbEnabled, true);
        expect(config.igdbEnabled, false);
      });

      test('handles empty map', () {
        final config = ApiConfig.fromMap({});
        expect(config.steamGridDbKey, isNull);
        expect(config.steamGridDbEnabled, false);
      });
    });

    group('toMap', () {
      test('converts to string map', () {
        final config = ApiConfig(
          steamGridDbKey: 'key',
          igdbClientId: 'cid',
          igdbEnabled: true,
          screenScraperEnabled: false,
        );
        final map = config.toMap();
        expect(map['steamGridDbKey'], 'key');
        expect(map['igdbClientId'], 'cid');
        expect(map['igdbEnabled'], 'true');
        expect(map['screenScraperEnabled'], 'false');
      });

      test('null values become empty strings', () {
        final config = ApiConfig();
        final map = config.toMap();
        expect(map['steamGridDbKey'], '');
        expect(map['igdbClientId'], '');
        expect(map['igdbClientSecret'], '');
      });
    });

    group('copyWith', () {
      test('copies with new values', () {
        final original = ApiConfig(steamGridDbKey: 'old');
        final copied = original.copyWith(steamGridDbKey: 'new');
        expect(copied.steamGridDbKey, 'new');
      });

      test('preserves unmodified fields', () {
        final original = ApiConfig(
          steamGridDbKey: 'key',
          igdbClientId: 'cid',
          igdbClientSecret: 'secret',
        );
        final copied = original.copyWith(steamGridDbKey: 'new-key');
        expect(copied.steamGridDbKey, 'new-key');
        expect(copied.igdbClientId, 'cid');
        expect(copied.igdbClientSecret, 'secret');
      });

      test('copyWith no args returns identical', () {
        final original = ApiConfig(
          steamGridDbKey: 'k',
          igdbEnabled: true,
        );
        final copied = original.copyWith();
        expect(copied.steamGridDbKey, 'k');
        expect(copied.igdbEnabled, true);
      });
    });

    group('roundtrip', () {
      test('fromMap -> toMap -> fromMap preserves data', () {
        final original = ApiConfig(
          steamGridDbKey: 'key123',
          igdbClientId: 'client',
          igdbClientSecret: 'secret',
          screenScraperUsername: 'user',
          screenScraperPassword: 'pass',
          steamGridDbEnabled: true,
          igdbEnabled: true,
          screenScraperEnabled: false,
        );
        final map = original.toMap();
        final restored = ApiConfig.fromMap(map);
        expect(restored.steamGridDbKey, original.steamGridDbKey);
        expect(restored.igdbClientId, original.igdbClientId);
        expect(restored.igdbClientSecret, original.igdbClientSecret);
        expect(restored.screenScraperUsername, original.screenScraperUsername);
        expect(restored.screenScraperPassword, original.screenScraperPassword);
        expect(restored.steamGridDbEnabled, original.steamGridDbEnabled);
        expect(restored.igdbEnabled, original.igdbEnabled);
        expect(restored.screenScraperEnabled, original.screenScraperEnabled);
      });
    });
  });
}
