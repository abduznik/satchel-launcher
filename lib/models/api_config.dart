class ApiConfig {
  final String? steamGridDbKey;
  final String? igdbClientId;
  final String? igdbClientSecret;
  final String? screenScraperUsername;
  final String? screenScraperPassword;
  final bool steamGridDbEnabled;
  final bool igdbEnabled;
  final bool screenScraperEnabled;

  ApiConfig({
    this.steamGridDbKey,
    this.igdbClientId,
    this.igdbClientSecret,
    this.screenScraperUsername,
    this.screenScraperPassword,
    this.steamGridDbEnabled = false,
    this.igdbEnabled = false,
    this.screenScraperEnabled = false,
  });

  Map<String, dynamic> toJson() => {
    'steamGridDbKey': steamGridDbKey,
    'igdbClientId': igdbClientId,
    'igdbClientSecret': igdbClientSecret,
    'screenScraperUsername': screenScraperUsername,
    'screenScraperPassword': screenScraperPassword,
    'steamGridDbEnabled': steamGridDbEnabled,
    'igdbEnabled': igdbEnabled,
    'screenScraperEnabled': screenScraperEnabled,
  };

  factory ApiConfig.fromJson(Map<String, dynamic> json) => ApiConfig(
    steamGridDbKey: json['steamGridDbKey'],
    igdbClientId: json['igdbClientId'],
    igdbClientSecret: json['igdbClientSecret'],
    screenScraperUsername: json['screenScraperUsername'],
    screenScraperPassword: json['screenScraperPassword'],
    steamGridDbEnabled: json['steamGridDbEnabled'] ?? false,
    igdbEnabled: json['igdbEnabled'] ?? false,
    screenScraperEnabled: json['screenScraperEnabled'] ?? false,
  );

  ApiConfig copyWith({
    String? steamGridDbKey,
    String? igdbClientId,
    String? igdbClientSecret,
    String? screenScraperUsername,
    String? screenScraperPassword,
    bool? steamGridDbEnabled,
    bool? igdbEnabled,
    bool? screenScraperEnabled,
  }) {
    return ApiConfig(
      steamGridDbKey: steamGridDbKey ?? this.steamGridDbKey,
      igdbClientId: igdbClientId ?? this.igdbClientId,
      igdbClientSecret: igdbClientSecret ?? this.igdbClientSecret,
      screenScraperUsername: screenScraperUsername ?? this.screenScraperUsername,
      screenScraperPassword: screenScraperPassword ?? this.screenScraperPassword,
      steamGridDbEnabled: steamGridDbEnabled ?? this.steamGridDbEnabled,
      igdbEnabled: igdbEnabled ?? this.igdbEnabled,
      screenScraperEnabled: screenScraperEnabled ?? this.screenScraperEnabled,
    );
  }

  bool get anyEnabled => steamGridDbEnabled || igdbEnabled || screenScraperEnabled;
}
