class Game {
  final String id;
  final String name;
  final String folderPath;
  final String exePath;
  final String? coverPath;
  final GameMetadata? metadata;
  final DateTime lastPlayed;
  final bool omniSaveEnabled;

  Game({
    required this.id,
    required this.name,
    required this.folderPath,
    required this.exePath,
    this.coverPath,
    this.metadata,
    DateTime? lastPlayed,
    this.omniSaveEnabled = true,
  }) : lastPlayed = lastPlayed ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'folderPath': folderPath,
    'exePath': exePath,
    'coverPath': coverPath,
    'metadata': metadata?.toJson(),
    'lastPlayed': lastPlayed.toIso8601String(),
    'omniSaveEnabled': omniSaveEnabled,
  };

  factory Game.fromJson(Map<String, dynamic> json) => Game(
    id: json['id'],
    name: json['name'],
    folderPath: json['folderPath'],
    exePath: json['exePath'],
    coverPath: json['coverPath'],
    metadata: json['metadata'] != null
        ? GameMetadata.fromJson(json['metadata'])
        : null,
    lastPlayed: DateTime.parse(json['lastPlayed']),
    omniSaveEnabled: json['omniSaveEnabled'] ?? true,
  );

  Game copyWith({
    String? name,
    String? coverPath,
    GameMetadata? metadata,
    DateTime? lastPlayed,
    bool? omniSaveEnabled,
  }) {
    return Game(
      id: id,
      name: name ?? this.name,
      folderPath: folderPath,
      exePath: exePath,
      coverPath: coverPath ?? this.coverPath,
      metadata: metadata ?? this.metadata,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      omniSaveEnabled: omniSaveEnabled ?? this.omniSaveEnabled,
    );
  }
}

class GameMetadata {
  final String? summary;
  final List<String> genres;
  final String? releaseDate;
  final String? developer;
  final String? publisher;
  final double? rating;
  final String? steamGridDbId;
  final String? igdbId;
  final String? screenScraperId;

  GameMetadata({
    this.summary,
    this.genres = const [],
    this.releaseDate,
    this.developer,
    this.publisher,
    this.rating,
    this.steamGridDbId,
    this.igdbId,
    this.screenScraperId,
  });

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'genres': genres,
    'releaseDate': releaseDate,
    'developer': developer,
    'publisher': publisher,
    'rating': rating,
    'steamGridDbId': steamGridDbId,
    'igdbId': igdbId,
    'screenScraperId': screenScraperId,
  };

  factory GameMetadata.fromJson(Map<String, dynamic> json) => GameMetadata(
    summary: json['summary'],
    genres: List<String>.from(json['genres'] ?? []),
    releaseDate: json['releaseDate'],
    developer: json['developer'],
    publisher: json['publisher'],
    rating: json['rating']?.toDouble(),
    steamGridDbId: json['steamGridDbId'],
    igdbId: json['igdbId'],
    screenScraperId: json['screenScraperId'],
  );
}
