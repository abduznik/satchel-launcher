import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../models/api_search_result.dart';
import '../models/game.dart';
import '../providers/api_provider.dart';
import '../providers/game_library_provider.dart';

/// Shows a search-result grid of game covers. User picks one and we
/// download full metadata (cover + banner + screenshots + info).
class ArtPickerDialog extends ConsumerStatefulWidget {
  final Game game;

  const ArtPickerDialog({super.key, required this.game});

  @override
  ConsumerState<ArtPickerDialog> createState() => _ArtPickerDialogState();
}

class _ArtPickerDialogState extends ConsumerState<ArtPickerDialog> {
  final _searchController = TextEditingController();
  List<ApiSearchResult> _results = [];
  bool _searching = false;
  bool _applying = false;
  String? _status;
  ApiSearchResult? _selected;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.game.displayName;
    // Auto-search on open
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _results = [];
      _selected = null;
      _status = null;
    });
    final svc = ref.read(metadataFetchServiceProvider);
    final results = await svc.searchCandidates(query);
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
        if (results.isEmpty) _status = 'No results found.';
      });
    }
  }

  Future<void> _applySelected() async {
    if (_selected == null) return;
    setState(() {
      _applying = true;
      _status = 'Downloading metadata & images…';
    });

    // Wait for IGDB auth if needed (provider may still be authenticating)
    final igdb = ref.read(igdbProvider);
    if (!igdb.isAuthenticated) {
      setState(() => _status = 'Waiting for IGDB auth…');
      for (var i = 0; i < 30 && !igdb.isAuthenticated; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    // Re-read service now that auth is ready
    final svc = ref.read(metadataFetchServiceProvider);
    print('[ArtPicker] fetchFull for ${widget.game.name} / selected=${_selected!.id}');
    final data = await svc.fetchFull(widget.game, _selected!, clearOld: true);
    print('[ArtPicker] cover=${data.coverPath} banner=${data.bannerPath} meta=${data.metadata != null ? "ok" : "null"}');

    if (!mounted) return;

    // Merge with existing metadata
    final existing = widget.game.metadata;
    final merged = (data.metadata ?? existing)?.copyWith(
          screenshots: data.metadata?.screenshots.isNotEmpty == true
              ? data.metadata!.screenshots
              : existing?.screenshots ?? [],
          videos: data.metadata?.videos.isNotEmpty == true
              ? data.metadata!.videos
              : existing?.videos ?? [],
        ) ??
        data.metadata;

    final updatedGame = widget.game.copyWith(
      coverPath: data.coverPath ?? widget.game.coverPath,
      bannerPath: data.bannerPath ?? widget.game.bannerPath,
      metadata: merged,
    );

    print('[ArtPicker] Updating game — cover=${updatedGame.coverPath} banner=${updatedGame.bannerPath}');
    await ref.read(gameLibraryProvider.notifier).updateGame(updatedGame);

    // Persist everything to meta.json so it survives rescan (offline use)
    await _saveMetaJson(updatedGame);

    // Small delay to let the provider state propagate before closing
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Write all game data to .indie/meta.json so it survives rescan.
  Future<void> _saveMetaJson(Game game) async {
    try {
      final indieDir = Directory(p.join(game.folderPath, '.indie'));
      await indieDir.create(recursive: true);
      final metaFile = File(p.join(indieDir.path, 'meta.json'));

      // Merge with any existing keys (e.g. omnisaveConfigured)
      Map<String, dynamic> existing = {};
      if (await metaFile.exists()) {
        try {
          existing =
              jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        } catch (_) {}
      }

      existing['coverPath'] = game.coverPath;
      existing['bannerPath'] = game.bannerPath;
      if (game.metadata != null) {
        existing.addAll(game.metadata!.toJson());
      }

      await metaFile.writeAsString(jsonEncode(existing));
      print('[ArtPicker] meta.json written for ${game.name}');
    } catch (e) {
      print('[ArtPicker] Failed to write meta.json: $e');
    }
  }

  Future<void> _browseLocalFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null && mounted) {
      final src = File(result.files.single.path!);
      final indieDir = Directory(p.join(widget.game.folderPath, '.indie'));
      await indieDir.create(recursive: true);
      final dest = File(p.join(indieDir.path, 'cover.jpg'));
      await src.copy(dest.path);
      print('[ArtPicker] Local cover copied to ${dest.path}');
      final updated = widget.game.copyWith(coverPath: dest.path);
      await ref.read(gameLibraryProvider.notifier).updateGame(updated);
      await _saveMetaJson(updated);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Column(
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select Game',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            // --- Search bar ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search game name…',
                        isDense: true,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _searching ? null : _search,
                    child: _searching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Search'),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // --- Results grid ---
            Expanded(
              child: _searching
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _status ?? 'Search for a game above.',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5)),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.65,
                          ),
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) {
                            final r = _results[i];
                            final isSelected = _selected?.id == r.id;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selected = isSelected ? null : r),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(ctx).colorScheme.primary
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: r.thumbnailUrl != null
                                            ? Image.network(
                                                r.thumbnailUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    _placeholder(ctx),
                                              )
                                            : _placeholder(ctx),
                                      ),
                                      Container(
                                        color: isSelected
                                            ? Theme.of(ctx)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.9)
                                            : Theme.of(ctx)
                                                .colorScheme
                                                .surface,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 4),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r.name,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? Colors.white
                                                    : null,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (r.year != null)
                                              Text(
                                                r.year!,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isSelected
                                                      ? Colors.white70
                                                      : Theme.of(ctx)
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(
                                                              alpha: 0.5),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),

            const Divider(height: 1),

            // --- Footer actions ---
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _applying ? null : _browseLocalFile,
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('Use Local File'),
                  ),
                  const Spacer(),
                  if (_status != null && _applying)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        _status!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: (_selected == null || _applying)
                        ? null
                        : _applySelected,
                    child: _applying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Apply'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext ctx) {
    return Container(
      color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.gamepad_outlined, size: 40),
    );
  }
}
