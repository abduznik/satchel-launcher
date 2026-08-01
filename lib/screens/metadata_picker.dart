import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game.dart';
import '../models/api_search_result.dart';
import '../providers/api_provider.dart';

class MetadataPicker extends ConsumerStatefulWidget {
  final Game game;

  const MetadataPicker({super.key, required this.game});

  @override
  ConsumerState<MetadataPicker> createState() => _MetadataPickerState();
}

class _MetadataPickerState extends ConsumerState<MetadataPicker> {
  List<ApiSearchResult> _searchResults = [];
  bool _isSearching = false;
  String? _selectedSource;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _searchForGame();
  }

  Future<void> _searchForGame() async {
    setState(() => _isSearching = true);

    final steamGridDb = ref.read(steamGridDbProvider);
    final igdbApi = ref.read(igdbProvider);
    final screenScraper = ref.read(screenScraperProvider);

    final results = <ApiSearchResult>[];

    // Search across all enabled APIs
    if (ref.read(apiConfigProvider).steamGridDbEnabled) {
      final sgdResults = await steamGridDb.search(widget.game.name);
      results.addAll(sgdResults);
    }

    if (ref.read(apiConfigProvider).igdbEnabled) {
      // Wait up to 3s for IGDB auth token if not yet ready
      if (!igdbApi.isAuthenticated) {
        for (var i = 0; i < 30; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (igdbApi.isAuthenticated) break;
        }
      }
      final igdbResults = await igdbApi.search(widget.game.name);
      results.addAll(igdbResults);
    }

    if (ref.read(apiConfigProvider).screenScraperEnabled) {
      final ssResults = await screenScraper.search(widget.game.name);
      results.addAll(ssResults);
    }

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1a1a2e),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Game Metadata',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.game.name,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white10, height: 1),

            // Search results
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFe94560)),
                ),
              )
            else if (_searchResults.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'No results found',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try adding API keys in Settings',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    final isSelected = _selectedId == result.id &&
                        _selectedSource == result.source;

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: const Color(0xFFe94560).withValues(alpha: 0.2),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: result.thumbnailUrl != null
                            ? Image.network(
                                result.thumbnailUrl!,
                                width: 40,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _sourceIcon(result.source),
                              )
                            : _sourceIcon(result.source),
                      ),
                      title: Text(
                        result.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        result.source.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Color(0xFFe94560))
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedId = result.id;
                          _selectedSource = result.source;
                        });
                      },
                    );
                  },
                ),
              ),

            const Divider(color: Colors.white10, height: 1),

            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Skip'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _selectedId != null
                        ? () => _applySelection()
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFe94560),
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceIcon(String source) {
    return Container(
      width: 40,
      height: 56,
      color: const Color(0xFF16213e),
      child: Center(
        child: Text(
          source[0].toUpperCase(),
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _applySelection() async {
    if (_selectedId == null || _selectedSource == null) return;

    // Fetch cover art
    String? coverUrl;
    GameMetadata? metadata;

    if (_selectedSource == 'steamgriddb') {
      coverUrl = await ref.read(steamGridDbProvider).getCoverUrl(_selectedId!);
    } else if (_selectedSource == 'igdb') {
      metadata = await ref.read(igdbProvider).getGameDetails(_selectedId!);
      coverUrl = await ref.read(igdbProvider).getCoverUrl(_selectedId!);
    } else if (_selectedSource == 'screenscraper') {
      coverUrl = await ref.read(screenScraperProvider).getCoverUrl(_selectedId!);
    }

    // Fall back to thumbnail from search result if no dedicated cover URL
    if (coverUrl == null) {
      final result = _searchResults.firstWhere(
        (r) => r.id == _selectedId && r.source == _selectedSource,
        orElse: () => _searchResults.first,
      );
      coverUrl = result.thumbnailUrl;
    }

    if (mounted) {
      Navigator.pop(context, {
        'metadata': metadata,
        'coverUrl': coverUrl,
      });
    }
  }
}
