import 'dart:io';
import 'package:dio/dio.dart';

class PcgamingwikiService {
  static const _apiBase = 'https://www.pcgamingwiki.com/w/api.php';
  static const _userAgent = 'ProjectIndie/1.0 (portable-game-launcher) Dio/5.0';
  final Dio _dio;

  PcgamingwikiService({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(headers: {'User-Agent': _userAgent}));

  /// Search for a page title on PCGamingWiki using opensearch.
  /// Tries multiple query strategies to handle dashes, colons, etc.
  Future<String?> findPageTitle(String gameName) async {
    final candidates = _buildSearchCandidates(gameName);
    for (final query in candidates) {
      final result = await _opensearch(query);
      if (result != null) {
        print('[PCGWiki] Found page "$result" via query "$query"');
        return result;
      }
    }

    // Last resort: try direct page fetch by sanitized name (PCGW may have that exact title)
    final directTitle = await _tryDirectPage(gameName);
    if (directTitle != null) {
      print('[PCGWiki] Found page "$directTitle" via direct fetch');
      return directTitle;
    }

    print('[PCGWiki] No page found for: $gameName');
    return null;
  }

  /// Build a list of search candidate strings to try in order.
  List<String> _buildSearchCandidates(String gameName) {
    final candidates = <String>[];
    // 1. Exact name
    candidates.add(gameName);

    // 2. Replace dashes/underscores with spaces
    final spacified = gameName.replaceAll(RegExp(r'[-_]'), ' ').trim();
    if (spacified != gameName) candidates.add(spacified);

    // 3. Strip subtitle (anything after : or –)
    final noSubtitle = gameName.split(RegExp(r'[:\u2013\u2014]')).first.trim();
    if (noSubtitle != gameName && noSubtitle.length > 3) candidates.add(noSubtitle);

    // 4. Strip subtitle from spacified version
    final spacifiedNoSub = spacified.split(RegExp(r'[:\u2013\u2014]')).first.trim();
    if (!candidates.contains(spacifiedNoSub) && spacifiedNoSub.length > 3) {
      candidates.add(spacifiedNoSub);
    }

    // 5. Remove all punctuation except spaces
    final noPunct = gameName.replaceAll(RegExp(r"[^\w\s]"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (!candidates.contains(noPunct) && noPunct.length > 3) candidates.add(noPunct);

    // 6. First two "words" (for very long names)
    final words = spacifiedNoSub.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length > 2) {
      final shortName = words.take(2).join(' ');
      if (!candidates.contains(shortName)) candidates.add(shortName);
    }

    return candidates.map((c) => c.trim()).where((c) => c.isNotEmpty).toSet().toList();
  }

  Future<String?> _opensearch(String query) async {
    try {
      final response = await _dio.get(_apiBase, queryParameters: {
        'action': 'opensearch',
        'search': query,
        'redirects': 'resolve',
        'limit': 5,
        'format': 'json',
      });
      final data = response.data;
      if (data is List && data.length >= 2) {
        final titles = data[1] as List;
        if (titles.isNotEmpty) return titles[0].toString();
      }
      return null;
    } catch (e) {
      print('[PCGWiki] opensearch error for "$query": $e');
      return null;
    }
  }

  /// Try fetching the page directly (PCGW redirects common name variants).
  Future<String?> _tryDirectPage(String gameName) async {
    // PCGW page titles use spaces and title-case; try the game name as-is
    try {
      final response = await _dio.get(_apiBase, queryParameters: {
        'action': 'parse',
        'redirects': '1',
        'prop': 'wikitext',
        'page': gameName,
        'format': 'json',
      });
      final parse = response.data?['parse'];
      if (parse != null && parse['title'] != null) {
        return parse['title'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get wikitext for a page title.
  Future<String?> _getWikitext(String pageTitle) async {
    try {
      final response = await _dio.get(_apiBase, queryParameters: {
        'action': 'parse',
        'redirects': '1',
        'prop': 'wikitext',
        'page': pageTitle,
        'format': 'json',
      });
      return response.data?['parse']?['wikitext']?['*'] as String?;
    } catch (e) {
      print('[PCGWiki] _getWikitext error: $e');
      return null;
    }
  }

  /// Get Windows save paths for a game by name.
  /// Returns list of raw paths (with {{p|...}} already expanded).
  /// [gameFolderPath] is used to resolve {{p|game}}.
  Future<List<String>> getSavePaths(String gameName, {String? gameFolderPath}) async {
    final title = await findPageTitle(gameName);
    if (title == null) {
      print('[PCGWiki] No page found for: $gameName');
      return [];
    }
    print('[PCGWiki] Found page: $title');

    final wikitext = await _getWikitext(title);
    if (wikitext == null) {
      print('[PCGWiki] No wikitext for: $title');
      return [];
    }

    return _extractWindowsSavePaths(wikitext, gameFolderPath: gameFolderPath);
  }

  List<String> _extractWindowsSavePaths(String wikitext, {String? gameFolderPath}) {
    final paths = <String>[];
    // Use a brace-depth-aware scan instead of regex, because the path content
    // itself contains nested {{p|...}} templates that break simple regex.
    const prefix = '{{Game data/saves|Windows|';
    var searchFrom = 0;
    while (true) {
      final start = wikitext.toLowerCase().indexOf(prefix.toLowerCase(), searchFrom);
      if (start == -1) break;
      final contentStart = start + prefix.length;
      // Scan forward with brace depth to find the closing }} of this template
      var depth = 2; // we opened {{ at 'start'
      var i = contentStart;
      while (i < wikitext.length && depth > 0) {
        if (i + 1 < wikitext.length && wikitext[i] == '{' && wikitext[i + 1] == '{') {
          depth += 2;
          i += 2;
        } else if (i + 1 < wikitext.length && wikitext[i] == '}' && wikitext[i + 1] == '}') {
          depth -= 2;
          if (depth <= 0) break;
          i += 2;
        } else {
          i++;
        }
      }
      final raw = wikitext.substring(contentStart, i).trim();
      searchFrom = i + 2;

      if (raw.isEmpty) continue;

      // The template may contain multiple pipe-separated paths:
      // {{Game data/saves|Windows|PATH1|PATH2}}
      // Split on top-level | (not inside {{ }}) to get individual paths.
      final rawPaths = _splitTopLevelPipes(raw);

      for (final rawPath in rawPaths) {
        if (rawPath.trim().isEmpty) continue;

        // Skip paths that are purely Steam-specific (Steam userdata, no user path)
        if (_isSteamOnlyPath(rawPath)) {
          print('[PCGWiki] Skipping Steam-only path: $rawPath');
          continue;
        }

        final expanded = _expandPcgwPath(rawPath.trim(), gameFolderPath: gameFolderPath);

        // Strip trailing glob/placeholder segments FIRST (*.sav, <uid>\*.json, etc.)
        // so that unresolved-token check runs on the cleaned path
        final cleaned = _stripGlobSuffix(expanded);

        // Skip if still has unresolved Steam tokens after stripping
        if (_hasUnresolvedSteamTokens(cleaned)) {
          print('[PCGWiki] Skipping unresolvable path: $rawPath → $cleaned');
          continue;
        }

        print('[PCGWiki] Save path: $rawPath → $cleaned');
        paths.add(cleaned);
      }
    }
    return paths;
  }

  /// Splits a string on | characters that are not inside {{ }} braces.
  List<String> _splitTopLevelPipes(String raw) {
    final parts = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < raw.length; i++) {
      if (i + 1 < raw.length && raw[i] == '{' && raw[i + 1] == '{') {
        depth += 2; i++;
      } else if (i + 1 < raw.length && raw[i] == '}' && raw[i + 1] == '}') {
        depth -= 2; i++;
      } else if (raw[i] == '|' && depth == 0) {
        parts.add(raw.substring(start, i));
        start = i + 1;
      }
    }
    parts.add(raw.substring(start));
    return parts;
  }

  bool _isSteamOnlyPath(String raw) {
    final lower = raw.toLowerCase();
    return lower.contains('{{p|steam}}') ||
        lower.contains('{{p|steamuserdataid}}') ||
        lower.contains('<steam') ||
        lower.contains('\\userdata\\') ||
        lower.contains('/userdata/');
  }

  bool _hasUnresolvedSteamTokens(String expanded) {
    return expanded.contains('<steam') ||
        expanded.contains('<uid>');
  }

  /// Strips trailing glob segments and user-id placeholders from an expanded path.
  /// e.g. C:\foo\<user-id>\*.json → C:\foo
  ///      C:\foo\saves\*.sav → C:\foo\saves
  String _stripGlobSuffix(String path) {
    var result = path;
    // Repeatedly strip trailing \<...> or \*.ext segments
    final trailingTokens = RegExp(r'[/\\](<[^>]+>|\*\.[a-zA-Z0-9]+|\*)[/\\]?$');
    while (trailingTokens.hasMatch(result)) {
      result = result.replaceFirst(trailingTokens, '');
    }
    return result.trim();
  }

  String _expandPcgwPath(String raw, {String? gameFolderPath}) {
    // Strip any [[Note N]] or {{Note|...}} refs embedded in the path
    var result = raw.replaceAll(RegExp(r'\[\[Note \d+\]\]', caseSensitive: false), '');
    result = result.replaceAll(RegExp(r'\{\{Note\|[^}]*\}\}', caseSensitive: false), '');
    result = result.trim();

    // Replace {{p|xxx}} tokens with OmniSave-portable paths (~/... notation)
    result = result.replaceAllMapped(RegExp(r'\{\{p\|([^}]+)\}\}', caseSensitive: false), (m) {
      return _resolveToken(m.group(1)!.toLowerCase().trim(), gameFolderPath);
    });

    // Also handle raw %VARIABLE% tokens — convert known ones to ~/... form
    result = result.replaceAllMapped(RegExp(r'%([^%]+)%'), (m) {
      return _resolveEnvToken(m.group(1)!);
    });

    // Normalize backslashes to forward slashes for OmniSave compatibility
    result = result.replaceAll('\\', '/');

    return result;
  }

  /// Resolves a {{p|key}} token to an OmniSave-portable path.
  /// Uses ~/ for anything under %USERPROFILE% so the path works on any PC.
  /// Uses ./ for game-relative paths.
  String _resolveToken(String key, String? gameFolderPath) {
    // Normalize: PCGW sometimes uses backslash-separated compound keys
    // e.g. "userprofile\appdata\locallow" — convert to forward slashes for matching
    final normKey = key.replaceAll('\\', '/').toLowerCase().trim();

    // Match compound path-style keys first (e.g. {{p|userprofile\appdata\locallow}})
    if (normKey == 'userprofile/appdata/locallow') return '~/AppData/LocalLow';
    if (normKey == 'userprofile/appdata/roaming') return '~/AppData/Roaming';
    if (normKey == 'userprofile/appdata/local')   return '~/AppData/Local';
    if (normKey == 'userprofile/documents')        return '~/Documents';
    if (normKey == 'userprofile/saved games')      return '~/Saved Games';

    switch (normKey) {
      case 'game':
        return './';
      case 'userprofile':
      case 'osprofile':
        return '~/';
      case 'appdata':
        return '~/AppData/Roaming';
      case 'localappdata':
        return '~/AppData/Local';
      case 'localappdatalow':
        return '~/AppData/LocalLow';
      case 'documents':
        return '~/Documents';
      case 'savedgames':
        return '~/Saved Games';
      case 'public':
        // Not user-relative; fall back to absolute on this machine
        return Platform.environment['PUBLIC'] ?? r'C:/Users/Public';
      case 'programfiles':
        return Platform.environment['ProgramFiles']?.replaceAll('\\', '/') ?? r'C:/Program Files';
      case 'programfilesx86':
        return Platform.environment['ProgramFiles(x86)']?.replaceAll('\\', '/') ?? r'C:/Program Files (x86)';
      case 'windir':
        return Platform.environment['WINDIR']?.replaceAll('\\', '/') ?? r'C:/Windows';
      case 'steam':
      case 'steamuserdataid':
      case 'uid':
        return '<$normKey>';
      default:
        final envVal = Platform.environment[normKey] ?? Platform.environment[normKey.toUpperCase()];
        return envVal?.replaceAll('\\', '/') ?? '<$normKey>';
    }
  }

  /// Converts a raw %VAR% token to OmniSave-portable form where possible.
  String _resolveEnvToken(String key) {
    switch (key.toUpperCase()) {
      case 'USERPROFILE':
        return '~/';
      case 'APPDATA':
        return '~/AppData/Roaming';
      case 'LOCALAPPDATA':
        return '~/AppData/Local';
      case 'TEMP':
      case 'TMP':
        return '~/AppData/Local/Temp';
      default:
        final val = Platform.environment[key] ?? Platform.environment[key.toUpperCase()];
        return val?.replaceAll('\\', '/') ?? '%$key%';
    }
  }

  /// Expands a portable OmniSave path (~/...) to an absolute path for display.
  /// This is what the user sees in the text field — not what gets written to omnisave.ini.
  static String expandForDisplay(String portablePath) {
    // Cross-platform: HOME on Unix, USERPROFILE on Windows (or via Wine).
    final userProfile = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    if (portablePath.startsWith('~/')) {
      return ('$userProfile\\${portablePath.substring(2)}')
          .replaceAll('/', '\\');
    }
    return portablePath.replaceAll('/', '\\');
  }
}
