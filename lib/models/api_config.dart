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

  /// Parse from a map that may have bools stored as strings ("true"/"false")
  factory ApiConfig.fromMap(Map<String, String> map) {
    bool parseBool(String? value) {
      if (value == null) return false;
      return value.toLowerCase() == 'true';
    }

    return ApiConfig(
      steamGridDbKey: _nonEmpty(map['steamGridDbKey']),
      igdbClientId: _nonEmpty(map['igdbClientId']),
      igdbClientSecret: _nonEmpty(map['igdbClientSecret']),
      screenScraperUsername: _nonEmpty(map['screenScraperUsername']),
      screenScraperPassword: _nonEmpty(map['screenScraperPassword']),
      steamGridDbEnabled: parseBool(map['steamGridDbEnabled']),
      igdbEnabled: parseBool(map['igdbEnabled']),
      screenScraperEnabled: parseBool(map['screenScraperEnabled']),
    );
  }

  static String? _nonEmpty(String? value) {
    if (value == null || value.isEmpty || value == 'null') return null;
    return value;
  }

  Map<String, String> toMap() => {
    'steamGridDbKey': steamGridDbKey ?? '',
    'igdbClientId': igdbClientId ?? '',
    'igdbClientSecret': igdbClientSecret ?? '',
    'screenScraperUsername': screenScraperUsername ?? '',
    'screenScraperPassword': screenScraperPassword ?? '',
    'steamGridDbEnabled': steamGridDbEnabled.toString(),
    'igdbEnabled': igdbEnabled.toString(),
    'screenScraperEnabled': screenScraperEnabled.toString(),
  };

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
}
