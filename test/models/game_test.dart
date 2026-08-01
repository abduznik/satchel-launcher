import 'package:flutter_test/flutter_test.dart';
import 'package:project_indie/models/game.dart';

void main() {
  group('Game', () {
    test('creates with required fields', () {
      final game = Game(
        id: 'test-id',
        name: 'Test Game',
        folderPath: '/games/test',
        exePath: '/games/test/game.exe',
      );
      expect(game.id, 'test-id');
      expect(game.name, 'Test Game');
      expect(game.folderPath, '/games/test');
      expect(game.exePath, '/games/test/game.exe');
      expect(game.coverPath, isNull);
      expect(game.bannerPath, isNull);
      expect(game.metadata, isNull);
      expect(game.omniSaveEnabled, true);
      expect(game.lastPlayed, isA<DateTime>());
    });

    test('defaults lastPlayed to now', () {
      final before = DateTime.now();
      final game = Game(
        id: 'id',
        name: 'name',
        folderPath: '/f',
        exePath: '/f/e.exe',
      );
      final after = DateTime.now();
      expect(game.lastPlayed.isAfter(before) || game.lastPlayed.isAtSameMomentAs(before), true);
      expect(game.lastPlayed.isBefore(after) || game.lastPlayed.isAtSameMomentAs(after), true);
    });

    test('respects custom lastPlayed', () {
      final custom = DateTime(2024, 1, 15);
      final game = Game(
        id: 'id',
        name: 'name',
        folderPath: '/f',
        exePath: '/f/e.exe',
        lastPlayed: custom,
      );
      expect(game.lastPlayed, custom);
    });

    test('serializes to JSON', () {
      final game = Game(
        id: 'id-1',
        name: 'My Game',
        folderPath: '/games/mygame',
        exePath: '/games/mygame/game.exe',
        coverPath: '/games/mygame/.indie/cover.jpg',
        bannerPath: '/games/mygame/.indie/banner.jpg',
        omniSaveEnabled: false,
      );
      final json = game.toJson();
      expect(json['id'], 'id-1');
      expect(json['name'], 'My Game');
      expect(json['folderPath'], '/games/mygame');
      expect(json['exePath'], '/games/mygame/game.exe');
      expect(json['coverPath'], '/games/mygame/.indie/cover.jpg');
      expect(json['bannerPath'], '/games/mygame/.indie/banner.jpg');
      expect(json['omniSaveEnabled'], false);
      expect(json['lastPlayed'], isA<String>());
    });

    test('deserializes from JSON', () {
      final json = {
        'id': 'id-1',
        'name': 'My Game',
        'folderPath': '/games/mygame',
        'exePath': '/games/mygame/game.exe',
        'coverPath': null,
        'bannerPath': null,
        'metadata': null,
        'lastPlayed': '2024-06-15T12:00:00.000',
        'omniSaveEnabled': true,
      };
      final game = Game.fromJson(json);
      expect(game.id, 'id-1');
      expect(game.name, 'My Game');
      expect(game.lastPlayed, DateTime(2024, 6, 15, 12, 0, 0));
      expect(game.omniSaveEnabled, true);
    });

    test('roundtrip JSON serialization', () {
      final original = Game(
        id: 'id-2',
        name: 'Roundtrip Game',
        folderPath: '/games/rt',
        exePath: '/games/rt/game.exe',
        lastPlayed: DateTime(2024, 3, 10, 8, 30),
      );
      final restored = Game.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.folderPath, original.folderPath);
      expect(restored.exePath, original.exePath);
      expect(restored.lastPlayed, original.lastPlayed);
    });

    test('copyWith preserves unmodified fields', () {
      final game = Game(
        id: 'id',
        name: 'Original',
        folderPath: '/f',
        exePath: '/f/e.exe',
        coverPath: '/f/cover.jpg',
      );
      final copied = game.copyWith(name: 'Updated');
      expect(copied.name, 'Updated');
      expect(copied.id, game.id);
      expect(copied.folderPath, game.folderPath);
      expect(copied.coverPath, game.coverPath);
    });

    test('copyWith with no args returns identical copy', () {
      final game = Game(
        id: 'id',
        name: 'Game',
        folderPath: '/f',
        exePath: '/f/e.exe',
      );
      final copied = game.copyWith();
      expect(copied.id, game.id);
      expect(copied.name, game.name);
      expect(copied.folderPath, game.folderPath);
    });
  });

  group('GameMetadata', () {
    test('creates with defaults', () {
      final meta = GameMetadata();
      expect(meta.summary, isNull);
      expect(meta.genres, isEmpty);
      expect(meta.releaseDate, isNull);
      expect(meta.developer, isNull);
      expect(meta.publisher, isNull);
      expect(meta.rating, isNull);
      expect(meta.ratingCount, isNull);
      expect(meta.screenshots, isEmpty);
      expect(meta.videos, isEmpty);
      expect(meta.steamGridDbId, isNull);
      expect(meta.igdbId, isNull);
      expect(meta.screenScraperId, isNull);
    });

    test('serializes to JSON', () {
      final meta = GameMetadata(
        summary: 'A great game',
        genres: ['Action', 'RPG'],
        releaseDate: '2024',
        developer: 'Dev Studio',
        publisher: 'Pub Inc',
        rating: 4.5,
        ratingCount: 100,
        screenshots: ['/s1.jpg', '/s2.jpg'],
        videos: [const IgdbVideo(name: 'Trailer', videoId: 'abc123')],
        steamGridDbId: 'sgdb-1',
        igdbId: 'igdb-2',
        screenScraperId: 'ss-3',
      );
      final json = meta.toJson();
      expect(json['summary'], 'A great game');
      expect(json['genres'], ['Action', 'RPG']);
      expect(json['developer'], 'Dev Studio');
      expect(json['rating'], 4.5);
      expect(json['screenshots'], ['/s1.jpg', '/s2.jpg']);
      expect(json['videos'], [{'name': 'Trailer', 'videoId': 'abc123'}]);
    });

    test('deserializes from JSON', () {
      final json = {
        'summary': 'Test summary',
        'genres': ['Puzzle'],
        'releaseDate': '2023',
        'developer': 'Test Dev',
        'publisher': 'Test Pub',
        'rating': 3.8,
        'ratingCount': 50,
        'screenshots': ['/test.jpg'],
        'videos': [{'name': 'Video', 'videoId': 'xyz'}],
        'steamGridDbId': 'sgdb-id',
        'igdbId': 'igdb-id',
        'screenScraperId': 'ss-id',
      };
      final meta = GameMetadata.fromJson(json);
      expect(meta.summary, 'Test summary');
      expect(meta.genres, ['Puzzle']);
      expect(meta.developer, 'Test Dev');
      expect(meta.rating, 3.8);
      expect(meta.videos.first.videoId, 'xyz');
    });

    test('handles null/missing JSON fields gracefully', () {
      final meta = GameMetadata.fromJson({});
      expect(meta.summary, isNull);
      expect(meta.genres, isEmpty);
      expect(meta.videos, isEmpty);
      expect(meta.screenshots, isEmpty);
    });

    test('roundtrip JSON serialization', () {
      final original = GameMetadata(
        summary: 'Roundtrip',
        genres: ['FPS', 'Action'],
        rating: 4.2,
        videos: [const IgdbVideo(name: 'Trailer', videoId: 'vid1')],
      );
      final restored = GameMetadata.fromJson(original.toJson());
      expect(restored.summary, original.summary);
      expect(restored.genres, original.genres);
      expect(restored.rating, original.rating);
      expect(restored.videos.length, original.videos.length);
    });

    test('copyWith preserves unmodified fields', () {
      final meta = GameMetadata(
        summary: 'Original',
        genres: ['RPG'],
        developer: 'Dev',
      );
      final copied = meta.copyWith(summary: 'Updated');
      expect(copied.summary, 'Updated');
      expect(copied.genres, ['RPG']);
      expect(copied.developer, 'Dev');
    });
  });

  group('IgdbVideo', () {
    test('creates with name and videoId', () {
      const video = IgdbVideo(name: 'Trailer', videoId: 'abc123');
      expect(video.name, 'Trailer');
      expect(video.videoId, 'abc123');
    });

    test('generates correct youtubeUrl', () {
      const video = IgdbVideo(name: 'Trailer', videoId: 'dQw4w9WgXcQ');
      expect(video.youtubeUrl, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    });

    test('generates correct thumbnailUrl', () {
      const video = IgdbVideo(name: 'Trailer', videoId: 'dQw4w9WgXcQ');
      expect(video.thumbnailUrl, 'https://img.youtube.com/vi/dQw4w9WgXcQ/mqdefault.jpg');
    });

    test('serializes to JSON', () {
      const video = IgdbVideo(name: 'Gameplay', videoId: 'vid1');
      expect(video.toJson(), {'name': 'Gameplay', 'videoId': 'vid1'});
    });

    test('deserializes from JSON', () {
      final video = IgdbVideo.fromJson({'name': 'Teaser', 'videoId': 'xyz'});
      expect(video.name, 'Teaser');
      expect(video.videoId, 'xyz');
    });

    test('handles missing JSON fields', () {
      final video = IgdbVideo.fromJson({});
      expect(video.name, '');
      expect(video.videoId, '');
    });
  });
}
