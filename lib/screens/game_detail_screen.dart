import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../models/game.dart';
import '../providers/api_provider.dart';
import '../providers/game_library_provider.dart';
import '../providers/playing_game_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';

import '../services/omnisave_service.dart';
import '../services/pcgamingwiki_service.dart';
import '../services/platform_service.dart';
import '../services/game_launch_service.dart';
import '../widgets/art_picker_dialog.dart';
import '../widgets/focus_effect_wrapper.dart';
import '../widgets/metadata_editor_dialog.dart';
import '../widgets/screenshot_viewer.dart';

class GameDetailScreen extends ConsumerStatefulWidget {
  final Game game;
  final bool openSaveDialog;

  const GameDetailScreen({super.key, required this.game, this.openSaveDialog = false});

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen> {
  late FocusNode _focusNode;
  final PcgamingwikiService _pcgamingwiki = PcgamingwikiService();
  bool _isLaunching = false;
  String _launchStatus = '';
  bool _isPushingSave = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    if (widget.openSaveDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _editSaveLocation());
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final cs = theme.theme.colorScheme;

    // Always read the live game from the provider so UI updates instantly
    // when cover/banner/metadata change without needing to reopen the screen.
    final game = ref.watch(gameLibraryProvider).valueOrNull
            ?.firstWhere((g) => g.id == widget.game.id,
                orElse: () => widget.game) ??
        widget.game;

    final meta = game.metadata;
    final hasBanner = game.bannerPath != null;
    final hasCover = game.coverPath != null;

    return Scaffold(
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(context).pop();
            } else if (event.logicalKey == LogicalKeyboardKey.enter) {
              _launchGame();
            }
          }
        },
        child: CustomScrollView(
          slivers: [
            // ----------------------------------------------------------------
            // Hero banner — 320px tall, cinematic gradient
            // ----------------------------------------------------------------
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              backgroundColor: cs.surface,
              leading: FocusEffectWrapper(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Banner image (or cover as fallback)
                    hasBanner
                        ? Image.file(
                            File(game.bannerPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildPlaceholder(theme),
                          )
                        : hasCover
                            ? Image.file(
                                File(game.coverPath!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildPlaceholder(theme),
                              )
                            : _buildPlaceholder(theme),

                    // Rich cinematic gradient: top-fade + bottom-black
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.35, 0.75, 1.0],
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                            Colors.black.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ----------------------------------------------------------------
            // Content
            // ----------------------------------------------------------------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover + title row — sits just below the collapsed AppBar
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Cover art (portrait) with shadow
                          if (hasCover)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(game.coverPath!),
                                  width: 120,
                                  height: 168,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(),
                                ),
                              ),
                            ),
                          if (hasCover) const SizedBox(width: 22),

                          // Title + meta block
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Title
                                Text(
                                  game.displayName,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
                                    letterSpacing: -0.3,
                                    height: 1.15,
                                  ),
                                ),
                                // Developer / Publisher / Year
                                if (meta != null) ...[
                                  const SizedBox(height: 7),
                                  Text(
                                    [
                                      if (meta.developer != null)
                                        meta.developer!,
                                      if (meta.publisher != null &&
                                          meta.publisher != meta.developer)
                                        meta.publisher!,
                                      if (meta.releaseDate != null)
                                        meta.releaseDate!,
                                    ].join('  ·  '),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: cs.onSurface.withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                                // Rating
                                if (meta?.rating != null) ...[
                                  const SizedBox(height: 8),
                                  _ratingBar(theme, meta!.rating!, meta.ratingCount),
                                ],
                                // Genres
                                if (meta != null && meta.genres.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: meta.genres
                                        .map((g) => Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: cs.primary.withValues(alpha: 0.14),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                g,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: cs.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                    ),

                    const SizedBox(height: 20),

                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Launch Button ───────────────────────────────
                          // Check if this game is playing
                          Consumer(
                            builder: (context, ref, _) {
                              final playing = ref.watch(playingGameProvider);
                              final isThisGamePlaying = playing != null && playing.game.id == widget.game.id;

                              return FocusEffectWrapper(
                                onTap: isThisGamePlaying
                                    ? () => stopCurrentGame(ref)
                                    : (_isLaunching ? null : _launchGame),
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: _isLaunching ? 0.65 : 1.0,
                                  child: Container(
                                    width: double.infinity,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: isThisGamePlaying
                                            ? [const Color(0xFFDC2626), const Color(0xFFEF4444)]
                                            : [
                                                cs.primary,
                                                Color.lerp(cs.primary, cs.secondary, 0.5) ?? cs.primary,
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: _isLaunching
                                          ? []
                                          : [
                                              BoxShadow(
                                                color: (isThisGamePlaying
                                                        ? const Color(0xFFDC2626)
                                                        : cs.primary)
                                                    .withValues(alpha: 0.38),
                                                blurRadius: 16,
                                                offset: const Offset(0, 5),
                                              ),
                                            ],
                                    ),
                                    child: Center(
                                      child: _isLaunching
                                          ? Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  _launchStatus.isNotEmpty ? _launchStatus.toUpperCase() : 'LAUNCHING...',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 2,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  isThisGamePlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                                  size: 30,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  isThisGamePlaying ? 'STOP' : 'PLAY',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 3,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 10),

                          // Action buttons row
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _editSaveLocation,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: cs.outline.withValues(alpha: 0.25)),
                                  foregroundColor:
                                      cs.onSurface.withValues(alpha: 0.65),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.folder_open, size: 15),
                                label: const Text('Save Location'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _changeCoverArt,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: cs.outline.withValues(alpha: 0.25)),
                                  foregroundColor:
                                      cs.onSurface.withValues(alpha: 0.65),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.image_search, size: 15),
                                label: const Text('Fetch Metadata'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _editMetadata,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: cs.outline.withValues(alpha: 0.25)),
                                  foregroundColor:
                                      cs.onSurface.withValues(alpha: 0.65),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.edit_note_rounded, size: 15),
                                label: const Text('Edit Metadata'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _isPushingSave ? null : _forcePushSave,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: cs.outline.withValues(alpha: 0.25)),
                                  foregroundColor:
                                      cs.onSurface.withValues(alpha: 0.65),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: _isPushingSave
                                    ? const SizedBox(
                                        width: 15,
                                        height: 15,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.cloud_upload_rounded, size: 15),
                                label: Text(_isPushingSave ? 'Pushing...' : 'Force Save Push'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // ── Divider ─────────────────────────────────────
                          Divider(
                            height: 1,
                            color: cs.outline.withValues(alpha: 0.12),
                          ),

                          // ── Summary ──────────────────────────────────────
                          if (meta?.summary != null) ...[
                            const SizedBox(height: 24),
                            _sectionHeader(theme, 'About'),
                            const SizedBox(height: 10),
                            Text(
                              meta!.summary!,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.75),
                                fontSize: 14,
                                height: 1.65,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Divider(height: 1, color: cs.outline.withValues(alpha: 0.12)),
                          ],

                          // ── Screenshots strip ─────────────────────────────
                          if (meta != null && meta.screenshots.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _sectionHeader(theme, 'Screenshots'),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 140,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: meta.screenshots.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (ctx, i) {
                                  final path = meta.screenshots[i];
                                  return GestureDetector(
                                    onTap: () => ScreenshotViewer.show(
                                      context,
                                      paths: meta.screenshots,
                                      initialIndex: i,
                                    ),
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox(
                                          width: 220,
                                          height: 140,
                                          child: Image.file(
                                            File(path),
                                            width: 220,
                                            height: 140,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              width: 220,
                                              height: 140,
                                              color: cs.surfaceContainerHighest,
                                              child: const Icon(
                                                  Icons.broken_image_outlined,
                                                  color: Colors.white38),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 28),
                            Divider(height: 1, color: cs.outline.withValues(alpha: 0.12)),
                          ],

                          // ── Videos strip ──────────────────────────────────
                          if (meta != null && meta.videos.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _sectionHeader(theme, 'Videos'),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 110,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: meta.videos.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (ctx, i) {
                                  final v = meta.videos[i];
                                  return GestureDetector(
                                    onTap: () =>
                                        _confirmOpenVideo(v.name, v.youtubeUrl),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            v.thumbnailUrl,
                                            height: 110,
                                            width: 195,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              width: 195,
                                              height: 110,
                                              color: cs.surfaceContainerHighest,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 6,
                                          left: 8,
                                          right: 8,
                                          child: Text(
                                            v.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              shadows: [Shadow(blurRadius: 4)],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 28),
                            Divider(height: 1, color: cs.outline.withValues(alpha: 0.12)),
                          ],

                          // ── Info cards row ────────────────────────────────
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              _infoCard(
                                theme,
                                icon: Icons.folder_rounded,
                                label: 'Location',
                                value: p.dirname(game.exePath),
                              ),
                              const SizedBox(width: 12),
                              _infoCard(
                                theme,
                                icon: Icons.terminal_rounded,
                                label: 'Executable',
                                value: p.basename(game.exePath),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingBar(ThemeProvider theme, double rating, int? count) {
    final cs = theme.theme.colorScheme;
    // IGDB rating is 0–100
    final stars = (rating / 20).clamp(0.0, 5.0);
    final full = stars.floor();
    final half = (stars - full) >= 0.5;
    return Row(
      children: [
        ...List.generate(5, (i) {
          if (i < full) {
            return Icon(Icons.star_rounded, size: 18, color: cs.primary);
          } else if (i == full && half) {
            return Icon(Icons.star_half_rounded, size: 18, color: cs.primary);
          }
          return Icon(Icons.star_outline_rounded,
              size: 18, color: cs.primary.withValues(alpha: 0.3));
        }),
        const SizedBox(width: 6),
        Text(
          '${rating.toStringAsFixed(0)}%${count != null ? '  ($count reviews)' : ''}',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(ThemeProvider theme, String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: theme.theme.colorScheme.primary,
      ),
    );
  }

  void _openUrl(String url) {
    PlatformService.openUrl(url);
  }

  Future<void> _confirmOpenVideo(String title, String url) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Video'),
        content: Text(
          '"$title" will open in your default browser.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.open_in_browser, size: 16),
            label: const Text('Open in Browser'),
          ),
        ],
      ),
    );
    if (confirmed == true) _openUrl(url);
  }

  Widget _buildPlaceholder(ThemeProvider theme) {
    return Container(
      color: theme.theme.colorScheme.surface,
      child: Center(
        child: Icon(
          Icons.gamepad_rounded,
          size: 80,
          color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.15),
        ),
      ),
    );
  }

  Widget _infoCard(ThemeProvider theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final cs = theme.theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cs.primary.withValues(alpha: 0.65), size: 18),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.45),
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.8),
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchGame() async {
    if (_isLaunching) return;

    // Guard: check if another game is already running
    final currentPlaying = ref.read(playingGameProvider);
    if (currentPlaying != null && currentPlaying.game.id != widget.game.id) {
      final shouldStop = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${currentPlaying.game.displayName} is running'),
          content: Text('Stop ${currentPlaying.game.displayName} and launch ${widget.game.displayName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Stop & Launch'),
            ),
          ],
        ),
      );
      if (shouldStop != true) return;
      await stopCurrentGame(ref);
      await Future.delayed(const Duration(seconds: 1));
    }

    setState(() {
      _isLaunching = true;
      _launchStatus = 'Preparing...';
    });

    // First-launch: show setup dialog if omnisave hasn't been configured yet
    final metaFile = File(p.join(widget.game.folderPath, '.indie', 'meta.json'));
    bool omnisaveConfigured = false;
    if (await metaFile.exists()) {
      try {
        final meta = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        omnisaveConfigured = meta['omnisaveConfigured'] == true;
      } catch (_) {}
    }

    if (!omnisaveConfigured) {
      if (mounted) await _showFirstLaunchDialog();
      if (!mounted || !_isLaunching) return;
    }

    if (!mounted) return;

    // Use the launch service for full lifecycle management
    final launchService = GameLaunchService();
    await launchService.launch(
      widget.game,
      ref,
      onStatusChanged: (status, message) {
        if (mounted) {
          setState(() {
            _launchStatus = message;
            if (status == LaunchStatus.done || status == LaunchStatus.error) {
              _isLaunching = false;
              _launchStatus = '';
            }
          });
        }
      },
    );

    // Ensure state is reset
    if (mounted) {
      setState(() {
        _isLaunching = false;
        _launchStatus = '';
      });
    }
  }

  Future<void> _forcePushSave() async {
    setState(() => _isPushingSave = true);
    final settings = ref.read(settingsProvider);
    final omniSave = OmniSaveService(savesBasePath: settings.resolvedSavesPath);
    bool success = false;
    try {
      success = await omniSave.forcePushSave(widget.game);
    } catch (e) {
      print('[GameDetailScreen] Force save push failed: $e');
    }
    if (!mounted) return;
    setState(() => _isPushingSave = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Save pushed to drive.'
            : 'Could not push save — configure a save location first.'),
      ),
    );
  }

  Future<void> _editSaveLocation() async {
    await _showFirstLaunchDialog(saveOnly: true);
  }

  Future<void> _changeCoverArt() async {
    // Read live game so the picker always has current state
    final liveGame = ref.read(gameLibraryProvider).valueOrNull
            ?.firstWhere((g) => g.id == widget.game.id,
                orElse: () => widget.game) ??
        widget.game;
    await showDialog<bool>(
      context: context,
      builder: (ctx) => ArtPickerDialog(game: liveGame),
    );
  }

  Future<void> _editMetadata() async {
    final liveGame = ref.read(gameLibraryProvider).valueOrNull
            ?.firstWhere((g) => g.id == widget.game.id,
                orElse: () => widget.game) ??
        widget.game;
    await showDialog<bool>(
      context: context,
      builder: (ctx) => MetadataEditorDialog(game: liveGame),
    );
  }

  Future<void> _showFirstLaunchDialog({bool saveOnly = false}) async {
    // Local state for the dialog
    String artworkStatus = saveOnly ? '— Skipped' : 'Press "Fetch" to auto-download artwork';
    bool artworkFetching = false;
    bool saveDetectionStarted = false;
    bool saveDetecting = false;
    bool cancelled = false;

    String savePathSource = '';
    bool skipSaveSync = false;
    bool saveDetectionDone = false;
    bool savesArePortable = false;
    // Display controller shows the expanded absolute path; portableSavePath is ~/... form
    final savePathController = TextEditingController();
    String portableSavePath = '';

    String toPortable(String abs) {
      // Cross-platform: HOME on Unix, USERPROFILE on Windows (or via Wine).
      final userProfile = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          '';
      if (userProfile.isNotEmpty &&
          abs.toLowerCase().startsWith(userProfile.toLowerCase())) {
        final rel = abs.substring(userProfile.length).replaceAll('\\', '/');
        return '~$rel';
      }
      return abs.replaceAll('\\', '/');
    }

    // Pre-fill save path from existing ini if editing
    if (saveOnly) {
      // Check meta.json for skipSaveSync flag first
      final metaFile = File(p.join(widget.game.folderPath, '.indie', 'meta.json'));
      if (await metaFile.exists()) {
        try {
          final meta = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
          if (meta['skipSaveSync'] == true) {
            skipSaveSync = true;
            savePathSource = 'Save sync disabled';
            saveDetectionDone = true;
          }
        } catch (_) {}
      }

      if (!skipSaveSync) {
        final iniFile = File(p.join(widget.game.folderPath, '.indie', 'omnisave.ini'));
        if (await iniFile.exists()) {
          final lines = await iniFile.readAsLines();
          for (final line in lines) {
            if (line.startsWith('Local_Path=')) {
              portableSavePath = line.substring('Local_Path='.length).trim();
              savePathController.text = portableSavePath;
              break;
            }
          }
        }
      }
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // artworkStarted flag is just used to prevent re-init; artwork is now manual

            // Initialize save detection state once
            if (!saveDetectionStarted) {
              saveDetectionStarted = true;
              if (saveOnly && savePathController.text.isNotEmpty) {
                setDialogState(() {
                  savePathSource = 'Current configured path';
                  saveDetectionDone = true;
                });
              } else {
                // Don't auto-detect — user triggers detection manually
                setDialogState(() => saveDetectionDone = true);
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  Expanded(
                    child: Text(saveOnly
                        ? 'Edit Save Location — ${widget.game.displayName}'
                        : 'Setting Up ${widget.game.displayName}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      cancelled = true;
                      Navigator.of(ctx).pop();
                    },
                    tooltip: 'Cancel',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Artwork section (hidden in saveOnly mode) ---
                    if (!saveOnly) ...[
                      Row(
                        children: [
                          artworkFetching
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  artworkStatus.startsWith('✓')
                                      ? Icons.check_circle
                                      : artworkStatus.startsWith('✗')
                                          ? Icons.cancel
                                          : Icons.image_outlined,
                                  size: 18,
                                  color: artworkStatus.startsWith('✓')
                                      ? Colors.green
                                      : artworkStatus.startsWith('✗')
                                          ? Colors.orange
                                          : null,
                                ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(artworkStatus,
                                style: const TextStyle(fontSize: 13)),
                          ),
                          OutlinedButton(
                            onPressed: artworkFetching
                                ? null
                                : () {
                                    setDialogState(() {
                                      artworkFetching = true;
                                      artworkStatus = 'Fetching...';
                                    });
                                    _autoFetchArtwork().then((got) {
                                      setDialogState(() {
                                        artworkFetching = false;
                                        artworkStatus = got
                                            ? '✓ Artwork saved'
                                            : '✗ No artwork found';
                                      });
                                    }).catchError((_) {
                                      setDialogState(() {
                                        artworkFetching = false;
                                        artworkStatus = '✗ Fetch failed';
                                      });
                                    });
                                  },
                            child: const Text('Fetch'),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                    ],

                    // --- Save Sync section ---
                    Row(
                      children: [
                        Text(
                          'Save Location',
                          style: Theme.of(ctx).textTheme.titleSmall,
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: saveDetecting
                              ? null
                              : () {
                                  setDialogState(() {
                                    saveDetecting = true;
                                    savePathSource = 'Searching PCGamingWiki...';
                                  });
                                  _pcgamingwiki
                                      .getSavePaths(widget.game.displayName,
                                          gameFolderPath:
                                              widget.game.folderPath)
                                      .then((paths) {
                                    if (paths.isNotEmpty) {
                                      final portable = paths.first;
                                      final isPortable = portable.startsWith('./');
                                      setDialogState(() {
                                        portableSavePath = portable;
                                        savePathController.text = portable;
                                        savePathSource =
                                            'Detected via PCGamingWiki';
                                        skipSaveSync = isPortable;
                                        savesArePortable = isPortable;
                                        saveDetecting = false;
                                      });
                                    } else {
                                      setDialogState(() {
                                        savePathSource =
                                            'Not found on PCGamingWiki';
                                        saveDetecting = false;
                                      });
                                    }
                                  }).catchError((_) {
                                    setDialogState(() {
                                      savePathSource = 'Detection failed';
                                      saveDetecting = false;
                                    });
                                  });
                                },
                          icon: saveDetecting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search, size: 14),
                          label: const Text('Detect'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    if (savePathSource.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        savePathSource,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (saveDetectionDone) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: savePathController,
                              enabled: !skipSaveSync,
                              onChanged: (val) {
                                portableSavePath = toPortable(val);
                              },
                              decoration: const InputDecoration(
                                hintText: 'Path to save folder',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: skipSaveSync
                                ? null
                                : () async {
                                    final dir =
                                        await FilePicker.getDirectoryPath();
                                    if (dir != null) {
                                      setDialogState(() {
                                        portableSavePath = toPortable(dir);
                                        savePathController.text = dir;
                                      });
                                    }
                                  },
                            child: const Text('Browse...'),
                          ),
                        ],
                      ),
                    ] else ...[
                      const LinearProgressIndicator(),
                    ],
                    if (savesArePortable) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Saves are inside the game folder — already portable, no sync needed.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    CheckboxListTile(
                      value: skipSaveSync,
                      onChanged: (val) =>
                          setDialogState(() => skipSaveSync = val ?? false),
                      title: const Text(
                        'Skip save sync (saves are portable / not needed)',
                        style: TextStyle(fontSize: 13),
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    cancelled = true;
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (skipSaveSync) {
                      // Remove any existing omnisave.ini so game launches directly
                      for (final path in [
                        p.join(widget.game.folderPath, 'OmniSave.ini'),
                        p.join(widget.game.folderPath, '.indie', 'omnisave.ini'),
                      ]) {
                        final f = File(path);
                        if (await f.exists()) await f.delete();
                      }
                      await _saveMetaJson({'omnisaveConfigured': true, 'skipSaveSync': true});
                    } else {
                      final pathToWrite = portableSavePath.isNotEmpty
                          ? portableSavePath
                          : toPortable(savePathController.text.trim());
                      if (pathToWrite.isNotEmpty) {
                        final settings = ref.read(settingsProvider);
                        final omniSave =
                            OmniSaveService(savesBasePath: settings.resolvedSavesPath);
                        await omniSave.generateConfig(
                          widget.game,
                          localSavePath: pathToWrite,
                        );
                      }
                      await _saveMetaJson({'omnisaveConfigured': true, 'skipSaveSync': false});
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: Text(saveOnly ? 'Save' : 'Launch'),
                ),
              ],
            );
          },
        );
      },
    );

    savePathController.dispose();

    // Return whether user cancelled (used by _launchGame to abort launch)
    if (cancelled && !saveOnly) {
      // Reset launching state so user can try again
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  /// Auto-fetch artwork using configured APIs (no manual picker). Returns true if cover was found.
  Future<bool> _autoFetchArtwork() async {
    // Check if cover already exists on disk (fetched by background scanner)
    final existingCover =
        File(p.join(widget.game.folderPath, '.indie', 'cover.jpg'));
    if (await existingCover.exists()) {
      if (mounted) {
        ref.read(gameLibraryProvider.notifier).updateGame(
              widget.game.copyWith(coverPath: existingCover.path),
            );
        await _saveMetaJson({'coverPath': existingCover.path});
      }
      return true;
    }

    final fetchService = ref.read(metadataFetchServiceProvider);
    final coverPath = await fetchService.fetchCover(widget.game);
    if (coverPath != null && mounted) {
      ref.read(gameLibraryProvider.notifier).updateGame(
            widget.game.copyWith(coverPath: coverPath),
          );
      await _saveMetaJson({'coverPath': coverPath});
      return true;
    }
    return false;
  }

  /// Writes or merges data into {game.folderPath}/.indie/meta.json.
  Future<void> _saveMetaJson(Map<String, dynamic> data) async {
    try {
      final indieDir = Directory(p.join(widget.game.folderPath, '.indie'));
      if (!await indieDir.exists()) {
        await indieDir.create(recursive: true);
      }

      final metaFile = File(p.join(indieDir.path, 'meta.json'));

      Map<String, dynamic> existing = {};
      if (await metaFile.exists()) {
        try {
          existing =
              jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        } catch (_) {}
      }

      existing.addAll(data);
      await metaFile.writeAsString(jsonEncode(existing));
    } catch (e) {
      print('[GameDetailScreen] Failed to write meta.json: $e');
    }
  }
}
