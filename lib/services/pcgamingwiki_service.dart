import 'dart:io';
import 'package:dio/dio.dart';

/// Result from PCGamingWiki search with confidence score.
class PcgwSearchResult {
  final String title;
  final double score; // 0.0 to 1.0
  final String url;

  PcgwSearchResult({required this.title, required this.score, required this.url});

  @override
  String toString() => '$title (${(score * 100).toStringAsFixed(0)}%)';
}

class PcgamingwikiService {
  static const _apiBase = 'https://www.pcgamingwiki.com/w/api.php';
  static const _userAgent = 'Satchel/1.0 (portable-game-launcher) Dio/5.0';
  final Dio _dio;

  PcgamingwikiService({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(headers: {'User-Agent': _userAgent}));

  // ---------------------------------------------------------------------------
  // Public API: find page title with confidence scoring
  // ---------------------------------------------------------------------------

  /// Searches PCGamingWiki for a game and returns the best match.
  /// If confidence is high (>0.9), returns the single best match.
  /// If confidence is medium (0.5-0.9), returns multiple candidates for user to pick.
  /// If no results, returns empty list.
  Future<List<PcgwSearchResult>> searchWithConfidence(String gameName) async {
    final results = <PcgwSearchResult>[];

    // Strategy 1: Search with exact name
    final exactResults = await _searchAndScore(gameName);
    results.addAll(exactResults);

    // Strategy 2: If no results, try with colon inserted before subtitle words
    if (results.isEmpty && !gameName.contains(':')) {
      final withColon = _insertColonBeforeSubtitle(gameName);
      if (withColon != null) {
        final colonResults = await _searchAndScore(withColon);
        results.addAll(colonResults);
      }
    }

    // Strategy 3: If still no results, try stripped punctuation
    if (results.isEmpty) {
      final stripped = gameName.replaceAll(RegExp(r"[^\w\s]"), ' ')
          .replaceAll(RegExp(r'\s+'), ' ').trim();
      if (stripped != gameName && stripped.length > 3) {
        final strippedResults = await _searchAndScore(stripped);
        results.addAll(strippedResults);
      }
    }

    // Dedupe by title, keep highest score
    final seen = <String, PcgwSearchResult>{};
    for (final r in results) {
      final key = r.title.toLowerCase();
      if (!seen.containsKey(key) || seen[key]!.score < r.score) {
        seen[key] = r;
      }
    }

    // Sort by score descending
    final deduped = seen.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return deduped;
  }

  /// Finds the best match for a game name.
  /// Returns the page title if confidence > 0.9, null otherwise.
  Future<String?> findPageTitle(String gameName) async {
    final results = await searchWithConfidence(gameName);
    if (results.isEmpty) return null;

    // Auto-select if top result is very confident
    if (results.first.score >= 0.9) {
      print('[PCGWiki] Auto-selected "${results.first.title}" (${results.first.score})');
      return results.first.title;
    }

    // Not confident enough — caller should show picker
    print('[PCGWiki] Low confidence for "$gameName": ${results.first.title} (${results.first.score})');
    return null;
  }

  // ---------------------------------------------------------------------------
  // Search + Score
  // ---------------------------------------------------------------------------

  Future<List<PcgwSearchResult>> _searchAndScore(String query) async {
    final results = <PcgwSearchResult>[];

    // Try opensearch
    final opensearchResults = await _opensearch(query);
    if (opensearchResults != null) {
      for (final title in opensearchResults) {
        // Skip series pages
        if (title.startsWith('Series:')) continue;
        final score = _computeScore(query, title);
        results.add(PcgwSearchResult(
          title: title,
          score: score,
          url: 'https://www.pcgamingwiki.com/wiki/${title.replaceAll(' ', '_')}',
        ));
      }
    }

    // Also try direct page fetch
    final directTitle = await _tryDirectPage(query);
    if (directTitle != null && !results.any((r) => r.title == directTitle)) {
      final score = _computeScore(query, directTitle);
      results.add(PcgwSearchResult(
        title: directTitle,
        score: score,
        url: 'https://www.pcgamingwiki.com/wiki/${directTitle.replaceAll(' ', '_')}',
      ));
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // Scoring: fuzzy string similarity
  // ---------------------------------------------------------------------------

  /// Computes similarity between query and result title (0.0 to 1.0).
  double _computeScore(String query, String title) {
    final q = query.toLowerCase().trim();
    final t = title.toLowerCase().trim();

    // Exact match
    if (q == t) return 1.0;

    // One contains the other
    if (t.contains(q)) return 0.95;
    if (q.contains(t)) return 0.9;

    // Levenshtein-based similarity
    final distance = _levenshtein(q, t);
    final maxLen = q.length > t.length ? q.length : t.length;
    if (maxLen == 0) return 0.0;

    final similarity = 1.0 - (distance / maxLen);

    // Bonus for word overlap
    final queryWords = q.split(RegExp(r'\s+')).toSet();
    final titleWords = t.split(RegExp(r'\s+')).toSet();
    final intersection = queryWords.intersection(titleWords);
    final wordBonus = intersection.length / (queryWords.length > titleWords.length ? queryWords.length : titleWords.length);

    return (similarity * 0.7 + wordBonus * 0.3).clamp(0.0, 1.0);
  }

  /// Levenshtein distance between two strings.
  int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(a.length + 1, (i) => List.generate(b.length + 1, (j) => 0));

    for (var i = 0; i <= a.length; i++) { matrix[i][0] = i; }
    for (var j = 0; j <= b.length; j++) { matrix[0][j] = j; }

    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[a.length][b.length];
  }

  // ---------------------------------------------------------------------------
  // Search helpers
  // ---------------------------------------------------------------------------

  /// Try inserting a colon before common subtitle words.
  /// "LEGO Batman Legacy of the Dark Knight" → "LEGO Batman: Legacy of the Dark Knight"
  /// Try inserting a colon before common subtitle words, or after the first word.
  /// "LEGO Batman Legacy of the Dark Knight" → "LEGO Batman: Legacy of the Dark Knight"
  /// "Danganronpa Trigger Happy Havoc" → "Danganronpa: Trigger Happy Havoc"
  String? _insertColonBeforeSubtitle(String gameName) {
    // Strategy A: Insert colon before known subtitle words
    final match = RegExp(r'\s+(Legacy|Subtitle|The|A|An|Of|Trigger)\s', caseSensitive: false)
        .firstMatch(gameName);
    if (match != null) {
      return '${gameName.substring(0, match.start)}:${gameName.substring(match.start)}';
    }

    // Strategy B: Insert colon after first word (common pattern: "Name: Subtitle")
    final words = gameName.split(' ');
    if (words.length >= 3) {
      return '${words[0]}: ${words.sublist(1).join(' ')}';
    }

    return null;
  }

  Future<List<String>?> _opensearch(String query) async {
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
        if (titles.isNotEmpty) return titles.cast<String>();
      }
      return null;
    } catch (e) {
      print('[PCGWiki] opensearch error for "$query": $e');
      return null;
    }
  }

  Future<String?> _tryDirectPage(String gameName) async {
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

  // ---------------------------------------------------------------------------
  // Wikitext parsing (unchanged)
  // ---------------------------------------------------------------------------

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

  Future<List<String>> getSavePaths(String gameName, {String? gameFolderPath}) async {
    // First try direct search
    var title = await findPageTitle(gameName);

    // If not found, try with confidence search and use best result
    if (title == null) {
      final results = await searchWithConfidence(gameName);
      if (results.isNotEmpty) {
        title = results.first.title;
        print('[PCGWiki] Using best match: $title (${results.first.score})');
      }
    }

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
    const prefix = '{{Game data/saves|Windows|';
    var searchFrom = 0;
    while (true) {
      final start = wikitext.toLowerCase().indexOf(prefix.toLowerCase(), searchFrom);
      if (start == -1) break;
      final contentStart = start + prefix.length;
      var depth = 2;
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

      final rawPaths = _splitTopLevelPipes(raw);

      for (final rawPath in rawPaths) {
        if (rawPath.trim().isEmpty) continue;
        if (_isSteamOnlyPath(rawPath)) {
          print('[PCGWiki] Skipping Steam-only path: $rawPath');
          continue;
        }

        final expanded = _expandPcgwPath(rawPath.trim(), gameFolderPath: gameFolderPath);
        final cleaned = _stripGlobSuffix(expanded);

        if (_hasUnresolvedSteamTokens(cleaned)) {
          print('[PCGWiki] Skipping unresolvable path: $rawPath -> $cleaned');
          continue;
        }

        print('[PCGWiki] Save path: $rawPath -> $cleaned');
        paths.add(cleaned);
      }
    }
    return paths;
  }

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
    return expanded.contains('<steam') || expanded.contains('<uid>');
  }

  String _stripGlobSuffix(String path) {
    var result = path;
    final trailingTokens = RegExp(r'[/\\](<[^>]+>|\*\.[a-zA-Z0-9]+|\*)[/\\]?$');
    while (trailingTokens.hasMatch(result)) {
      result = result.replaceFirst(trailingTokens, '');
    }
    return result.trim();
  }

  String _expandPcgwPath(String raw, {String? gameFolderPath}) {
    var result = raw.replaceAll(RegExp(r'\[\[Note \d+\]\]', caseSensitive: false), '');
    result = result.replaceAll(RegExp(r'\{\{Note\|[^}]*\}\}', caseSensitive: false), '');
    result = result.trim();

    result = result.replaceAllMapped(RegExp(r'\{\{p\|([^}]+)\}\}', caseSensitive: false), (m) {
      return _resolveToken(m.group(1)!.toLowerCase().trim(), gameFolderPath);
    });

    result = result.replaceAllMapped(RegExp(r'%([^%]+)%'), (m) {
      return _resolveEnvToken(m.group(1)!);
    });

    result = result.replaceAll('\\', '/');
    return result;
  }

  String _resolveToken(String key, String? gameFolderPath) {
    final normKey = key.replaceAll('\\', '/').toLowerCase().trim();

    if (normKey == 'userprofile/appdata/locallow') return '~/AppData/LocalLow';
    if (normKey == 'userprofile/appdata/roaming') return '~/AppData/Roaming';
    if (normKey == 'userprofile/appdata/local') return '~/AppData/Local';
    if (normKey == 'userprofile/documents') return '~/Documents';
    if (normKey == 'userprofile/saved games') return '~/Saved Games';

    switch (normKey) {
      case 'game': return './';
      case 'userprofile':
      case 'osprofile': return '~/';
      case 'appdata': return '~/AppData/Roaming';
      case 'localappdata': return '~/AppData/Local';
      case 'localappdatalow': return '~/AppData/LocalLow';
      case 'documents': return '~/Documents';
      case 'savedgames': return '~/Saved Games';
      case 'public': return Platform.environment['PUBLIC'] ?? r'C:/Users/Public';
      case 'programfiles': return Platform.environment['ProgramFiles']?.replaceAll('\\', '/') ?? r'C:/Program Files';
      case 'programfilesx86': return Platform.environment['ProgramFiles(x86)']?.replaceAll('\\', '/') ?? r'C:/Program Files (x86)';
      case 'windir': return Platform.environment['WINDIR']?.replaceAll('\\', '/') ?? r'C:/Windows';
      case 'steam':
      case 'steamuserdataid':
      case 'uid': return '<$normKey>';
      default:
        final envVal = Platform.environment[normKey] ?? Platform.environment[normKey.toUpperCase()];
        return envVal?.replaceAll('\\', '/') ?? '<$normKey>';
    }
  }

  String _resolveEnvToken(String key) {
    switch (key.toUpperCase()) {
      case 'USERPROFILE': return '~/';
      case 'APPDATA': return '~/AppData/Roaming';
      case 'LOCALAPPDATA': return '~/AppData/Local';
      case 'TEMP':
      case 'TMP': return '~/AppData/Local/Temp';
      default:
        final val = Platform.environment[key] ?? Platform.environment[key.toUpperCase()];
        return val?.replaceAll('\\', '/') ?? '%$key%';
    }
  }

  static String expandForDisplay(String portablePath) {
    final userProfile = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    if (portablePath.startsWith('~/')) {
      return ('$userProfile\\${portablePath.substring(2)}').replaceAll('/', '\\');
    }
    return portablePath.replaceAll('/', '\\');
  }
}
