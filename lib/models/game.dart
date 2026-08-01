class Game {
  final String id;
  final String name;
  final String folderPath;
  final String exePath;
  final String? coverPath;
  final String? bannerPath;
  final GameMetadata? metadata;
  final DateTime lastPlayed;
  final bool omniSaveEnabled;

  Game({
    required this.id,
    required this.name,
    required this.folderPath,
    required this.exePath,
    this.coverPath,
    this.bannerPath,
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
    'bannerPath': bannerPath,
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
    bannerPath: json['bannerPath'],
    metadata: json['metadata'] != null
        ? GameMetadata.fromJson(json['metadata'])
        : null,
    lastPlayed: DateTime.parse(json['lastPlayed']),
    omniSaveEnabled: json['omniSaveEnabled'] ?? true,
  );

  Game copyWith({
    String? name,
    String? coverPath,
    String? bannerPath,
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
      bannerPath: bannerPath ?? this.bannerPath,
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
  final int? ratingCount;
  final List<String> screenshots; // local file paths
  final List<IgdbVideo> videos;
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
    this.ratingCount,
    this.screenshots = const [],
    this.videos = const [],
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
    'ratingCount': ratingCount,
    'screenshots': screenshots,
    'videos': videos.map((v) => v.toJson()).toList(),
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
    ratingCount: json['ratingCount'] as int?,
    screenshots: List<String>.from(json['screenshots'] ?? []),
    videos: (json['videos'] as List? ?? [])
        .map((v) => IgdbVideo.fromJson(v as Map<String, dynamic>))
        .toList(),
    steamGridDbId: json['steamGridDbId'],
    igdbId: json['igdbId'],
    screenScraperId: json['screenScraperId'],
  );

  GameMetadata copyWith({
    String? summary,
    List<String>? genres,
    String? releaseDate,
    String? developer,
    String? publisher,
    double? rating,
    int? ratingCount,
    List<String>? screenshots,
    List<IgdbVideo>? videos,
    String? steamGridDbId,
    String? igdbId,
    String? screenScraperId,
  }) {
    return GameMetadata(
      summary: summary ?? this.summary,
      genres: genres ?? this.genres,
      releaseDate: releaseDate ?? this.releaseDate,
      developer: developer ?? this.developer,
      publisher: publisher ?? this.publisher,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      screenshots: screenshots ?? this.screenshots,
      videos: videos ?? this.videos,
      steamGridDbId: steamGridDbId ?? this.steamGridDbId,
      igdbId: igdbId ?? this.igdbId,
      screenScraperId: screenScraperId ?? this.screenScraperId,
    );
  }
}

class IgdbVideo {
  final String name;
  final String videoId; // YouTube video ID

  const IgdbVideo({required this.name, required this.videoId});

  String get youtubeUrl => 'https://www.youtube.com/watch?v=$videoId';
  String get thumbnailUrl =>
      'https://img.youtube.com/vi/$videoId/mqdefault.jpg';

  Map<String, dynamic> toJson() => {'name': name, 'videoId': videoId};

  factory IgdbVideo.fromJson(Map<String, dynamic> j) =>
      IgdbVideo(name: j['name'] ?? '', videoId: j['videoId'] ?? '');
}
