import 'package:flutter_test/flutter_test.dart';
import 'package:satchel/models/game.dart';

/// Replicates the matching logic from search_provider.dart for unit testing.
/// Note: the provider lowercases the query before calling this, so queries
/// here should already be lowercase to match real behavior.
bool _matchesQuery(Game game, String query) {
  if (game.name.toLowerCase().contains(query)) return true;
  final meta = game.metadata;
  if (meta == null) return false;
  if (meta.summary != null && meta.summary!.toLowerCase().contains(query)) return true;
  if (meta.genres.any((g) => g.toLowerCase().contains(query))) return true;
  if (meta.developer != null && meta.developer!.toLowerCase().contains(query)) return true;
  if (meta.publisher != null && meta.publisher!.toLowerCase().contains(query)) return true;
  if (meta.releaseDate != null && meta.releaseDate!.toLowerCase().contains(query)) return true;
  return false;
}

int _relevanceScore(Game game, String query) {
  int score = 0;
  final nameLower = game.name.toLowerCase();
  if (nameLower == query) return 100;
  if (nameLower.startsWith(query)) score += 50;
  if (nameLower.contains(query)) score += 30;
  final meta = game.metadata;
  if (meta != null) {
    if (meta.genres.any((g) => g.toLowerCase().contains(query))) score += 10;
    if (meta.developer?.toLowerCase().contains(query) == true) score += 8;
    if (meta.publisher?.toLowerCase().contains(query) == true) score += 8;
    if (meta.summary?.toLowerCase().contains(query) == true) score += 5;
  }
  return score;
}

Game _makeGame({
  required String name,
  String? summary,
  List<String> genres = const [],
  String? developer,
  String? publisher,
}) {
  return Game(
    id: name.hashCode.toString(),
    name: name,
    folderPath: '/games/$name',
    exePath: '/games/$name/game.exe',
    metadata: (summary != null || genres.isNotEmpty || developer != null || publisher != null)
        ? GameMetadata(
            summary: summary,
            genres: genres,
            developer: developer,
            publisher: publisher,
          )
        : null,
  );
}

void main() {
  group('Search matching', () {
    test('matches by game name (folder name)', () {
      final game = _makeGame(name: 'Prince of Persia - TST');
      expect(_matchesQuery(game, 'prince'), true);
      expect(_matchesQuery(game, 'persia'), true);
      expect(_matchesQuery(game, 'tst'), true);
      expect(_matchesQuery(game, 'pop'), false);
    });

    test('matches by genre', () {
      final game = _makeGame(name: 'Some Game', genres: ['Action', 'RPG']);
      expect(_matchesQuery(game, 'action'), true);
      expect(_matchesQuery(game, 'rpg'), true);
      expect(_matchesQuery(game, 'puzzle'), false);
    });

    test('matches by developer', () {
      final game = _makeGame(name: 'Game', developer: 'Naughty Dog');
      expect(_matchesQuery(game, 'naughty'), true);
      expect(_matchesQuery(game, 'dog'), true);
      expect(_matchesQuery(game, 'rockstar'), false);
    });

    test('matches by publisher', () {
      final game = _makeGame(name: 'Game', publisher: 'Electronic Arts');
      expect(_matchesQuery(game, 'electronic'), true);
      expect(_matchesQuery(game, 'ea'), false);
    });

    test('matches by summary', () {
      final game = _makeGame(name: 'Game', summary: 'An epic adventure game');
      expect(_matchesQuery(game, 'epic'), true);
      expect(_matchesQuery(game, 'adventure'), true);
    });

    test('matches by release date', () {
      final gameWithDate = Game(
        id: '1',
        name: 'Game',
        folderPath: '/f',
        exePath: '/f/e.exe',
        metadata: GameMetadata(releaseDate: '2024'),
      );
      expect(_matchesQuery(gameWithDate, '2024'), true);
      expect(_matchesQuery(gameWithDate, '2023'), false);
    });

    test('case insensitive matching', () {
      final game = _makeGame(name: 'The Witcher 3');
      expect(_matchesQuery(game, 'witcher'), true);
      expect(_matchesQuery(game, 'the'), true);
    });

    test('no match returns false', () {
      final game = _makeGame(name: 'Halo');
      expect(_matchesQuery(game, 'call of duty'), false);
    });

    test('game without metadata only matches name', () {
      final game = _makeGame(name: 'Simple Game');
      expect(_matchesQuery(game, 'simple'), true);
      expect(_matchesQuery(game, 'action'), false);
    });
  });

  group('Relevance scoring', () {
    test('exact name match scores highest', () {
      final game = _makeGame(name: 'test');
      expect(_relevanceScore(game, 'test'), 100);
    });

    test('name starting with query scores high', () {
      final game = _makeGame(name: 'testing game');
      // starts with (50) + contains (30) = 80
      expect(_relevanceScore(game, 'test'), 80);
    });

    test('name containing query scores medium', () {
      final game = _makeGame(name: 'the best test game');
      final score = _relevanceScore(game, 'test');
      expect(score, 30); // contains only
    });

    test('genre match adds score', () {
      final game = _makeGame(name: 'Game', genres: ['Action']);
      expect(_relevanceScore(game, 'action'), 10);
    });

    test('developer match adds score', () {
      final game = _makeGame(name: 'Game', developer: 'Naughty Dog');
      expect(_relevanceScore(game, 'naughty'), 8);
    });

    test('publisher match adds score', () {
      final game = _makeGame(name: 'Game', publisher: 'EA');
      expect(_relevanceScore(game, 'ea'), 8);
    });

    test('summary match adds score', () {
      final game = _makeGame(name: 'Game', summary: 'Epic adventure');
      expect(_relevanceScore(game, 'epic'), 5);
    });

    test('no match scores 0', () {
      final game = _makeGame(name: 'Halo');
      expect(_relevanceScore(game, 'call of duty'), 0);
    });

    test('combined scores stack', () {
      final game = _makeGame(
        name: 'Test Game',
        genres: ['Action'],
        developer: 'Test Studio',
      );
      // "test game" starts with "test" (50) + contains "test" (30) + developer "test" (8) = 88
      final score = _relevanceScore(game, 'test');
      expect(score, 88);
    });
  });

  group('Search priority — IGDB name vs folder name', () {
    test('IGDB metadata enriches search but folder name is primary', () {
      final game = _makeGame(
        name: 'Prince of Persia - TST',
        summary: 'Prince of Persia: The Sand of Time is a platform game',
        genres: ['Action', 'Platformer'],
        developer: 'Ubisoft Montreal',
      );

      // Folder name match
      expect(_matchesQuery(game, 'prince'), true);
      expect(_matchesQuery(game, 'tst'), true);

      // IGDB metadata match (summary contains the real name)
      expect(_matchesQuery(game, 'sand of time'), true);
      expect(_matchesQuery(game, 'ubisoft'), true);
      expect(_matchesQuery(game, 'platformer'), true);

      // Folder name should score higher than summary match
      final folderScore = _relevanceScore(game, 'prince');
      final metaScore = _relevanceScore(game, 'sand of time');
      expect(folderScore, greaterThan(metaScore));
    });
  });
}
