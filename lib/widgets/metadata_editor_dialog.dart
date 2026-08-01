import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../models/game.dart';
import '../providers/game_library_provider.dart';

/// Full metadata editor dialog for games that IGDB can't scrape,
/// or for manual correction of auto-detected metadata.
class MetadataEditorDialog extends ConsumerStatefulWidget {
  final Game game;

  const MetadataEditorDialog({super.key, required this.game});

  @override
  ConsumerState<MetadataEditorDialog> createState() => _MetadataEditorDialogState();
}

class _MetadataEditorDialogState extends ConsumerState<MetadataEditorDialog> {
  late TextEditingController _nameController;
  late TextEditingController _summaryController;
  late TextEditingController _developerController;
  late TextEditingController _publisherController;
  late TextEditingController _releaseDateController;
  late TextEditingController _ratingController;
  late TextEditingController _genreController;
  late List<String> _genres;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final meta = widget.game.metadata;
    _nameController = TextEditingController(text: widget.game.name);
    _summaryController = TextEditingController(text: meta?.summary ?? '');
    _developerController = TextEditingController(text: meta?.developer ?? '');
    _publisherController = TextEditingController(text: meta?.publisher ?? '');
    _releaseDateController = TextEditingController(text: meta?.releaseDate ?? '');
    _ratingController = TextEditingController(
      text: meta?.rating != null ? meta!.rating!.toStringAsFixed(0) : '',
    );
    _genreController = TextEditingController();
    _genres = List<String>.from(meta?.genres ?? []);

    _nameController.addListener(_onChanged);
    _summaryController.addListener(_onChanged);
    _developerController.addListener(_onChanged);
    _publisherController.addListener(_onChanged);
    _releaseDateController.addListener(_onChanged);
    _ratingController.addListener(_onChanged);
  }

  void _onChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _summaryController.dispose();
    _developerController.dispose();
    _publisherController.dispose();
    _releaseDateController.dispose();
    _ratingController.dispose();
    _genreController.dispose();
    super.dispose();
  }

  void _addGenre() {
    final text = _genreController.text.trim();
    if (text.isNotEmpty && !_genres.contains(text)) {
      setState(() {
        _genres.add(text);
        _genreController.clear();
        _hasChanges = true;
      });
    }
  }

  void _removeGenre(String genre) {
    setState(() {
      _genres.remove(genre);
      _hasChanges = true;
    });
  }

  Future<void> _save() async {
    final ratingText = _ratingController.text.trim();
    double? rating;
    if (ratingText.isNotEmpty) {
      rating = double.tryParse(ratingText);
      if (rating != null) {
        // Clamp to 0–100 range (IGDB scale)
        rating = rating.clamp(0.0, 100.0);
      }
    }

    final updatedMeta = GameMetadata(
      summary: _summaryController.text.trim().isNotEmpty
          ? _summaryController.text.trim()
          : null,
      genres: _genres,
      releaseDate: _releaseDateController.text.trim().isNotEmpty
          ? _releaseDateController.text.trim()
          : null,
      developer: _developerController.text.trim().isNotEmpty
          ? _developerController.text.trim()
          : null,
      publisher: _publisherController.text.trim().isNotEmpty
          ? _publisherController.text.trim()
          : null,
      rating: rating,
      ratingCount: widget.game.metadata?.ratingCount,
      screenshots: widget.game.metadata?.screenshots ?? [],
      videos: widget.game.metadata?.videos ?? [],
      steamGridDbId: widget.game.metadata?.steamGridDbId,
      igdbId: widget.game.metadata?.igdbId,
      screenScraperId: widget.game.metadata?.screenScraperId,
    );

    // Update the game with new name and metadata
    final updatedGame = widget.game.copyWith(
      name: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : widget.game.name,
      metadata: updatedMeta,
    );

    // Save to provider (updates Hive)
    await ref.read(gameLibraryProvider.notifier).updateGame(updatedGame);

    // Also save to meta.json on disk
    await _saveMetaJson(updatedGame);

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _saveMetaJson(Game game) async {
    try {
      final metaDir = Directory(p.join(game.folderPath, '.indie'));
      if (!await metaDir.exists()) {
        await metaDir.create(recursive: true);
      }
      final metaFile = File(p.join(game.folderPath, '.indie', 'meta.json'));

      // Read existing meta.json to preserve non-metadata fields
      Map<String, dynamic> existing = {};
      if (await metaFile.exists()) {
        try {
          existing = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        } catch (_) {}
      }

      // Merge metadata into existing
      existing['name'] = game.name;
      existing['coverPath'] = game.coverPath;
      existing['bannerPath'] = game.bannerPath;
      if (game.metadata != null) {
        existing['metadata'] = game.metadata!.toJson();
      }

      await metaFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(existing),
      );
    } catch (e) {
      print('[MetadataEditor] Failed to save meta.json: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.edit_note_rounded, color: cs.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Metadata',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          'Override metadata for this game',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context, false),
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outline.withValues(alpha: 0.08)),

            // ── Scrollable content ───────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                children: [
                  // Game Name
                  _FieldSection(
                    label: 'GAME NAME',
                    child: _EditorField(
                      controller: _nameController,
                      hint: 'Game title',
                    ),
                  ),

                  // Summary
                  _FieldSection(
                    label: 'SUMMARY',
                    child: _EditorField(
                      controller: _summaryController,
                      hint: 'Game description or summary',
                      maxLines: 3,
                    ),
                  ),

                  // Developer / Publisher
                  Row(
                    children: [
                      Expanded(
                        child: _FieldSection(
                          label: 'DEVELOPER',
                          child: _EditorField(
                            controller: _developerController,
                            hint: 'Studio name',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FieldSection(
                          label: 'PUBLISHER',
                          child: _EditorField(
                            controller: _publisherController,
                            hint: 'Publisher name',
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Release Date / Rating
                  Row(
                    children: [
                      Expanded(
                        child: _FieldSection(
                          label: 'RELEASE DATE',
                          child: _EditorField(
                            controller: _releaseDateController,
                            hint: 'e.g. 2024 or Jan 2024',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FieldSection(
                          label: 'RATING (0-100)',
                          child: _EditorField(
                            controller: _ratingController,
                            hint: 'e.g. 85',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Genres
                  _FieldSection(
                    label: 'CATEGORIES / GENRES',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Genre chips
                        if (_genres.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _genres.map((g) => Chip(
                              label: Text(g, style: TextStyle(fontSize: 12, color: cs.onSurface)),
                              deleteIcon: Icon(Icons.close, size: 14, color: cs.onSurface.withValues(alpha: 0.5)),
                              onDeleted: () => _removeGenre(g),
                              backgroundColor: cs.primary.withValues(alpha: 0.12),
                              side: BorderSide.none,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            )).toList(),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Add genre field
                        Row(
                          children: [
                            Expanded(
                              child: _EditorField(
                                controller: _genreController,
                                hint: 'Add a genre or category',
                                onSubmitted: (_) => _addGenre(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _AddButton(
                              label: 'Add',
                              onTap: _addGenre,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Footer buttons ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SaveButton(
                    label: 'Save Changes',
                    enabled: _hasChanges,
                    onTap: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ───────────────────────────────────────────────────────────

class _FieldSection extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _EditorField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType keyboardType;
  final ValueChanged<String>? onSubmitted;

  const _EditorField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: TextStyle(color: cs.onSurface, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.3),
          fontSize: 13,
        ),
        filled: true,
        fillColor: cs.onSurface.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.primary,
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _SaveButton({required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.2);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? color : color.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: enabled ? Colors.white : cs.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}
