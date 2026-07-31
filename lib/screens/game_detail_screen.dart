import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../models/game.dart';
import '../providers/game_library_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';

import '../services/omnisave_service.dart';
import '../services/pcgamingwiki_service.dart';
import '../widgets/focus_effect_wrapper.dart';

class GameDetailScreen extends ConsumerStatefulWidget {
  final Game game;

  const GameDetailScreen({super.key, required this.game});

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen> {
  late FocusNode _focusNode;
  final PcgamingwikiService _pcgamingwiki = PcgamingwikiService();
  SaveGameInfo? _saveInfo;
  bool _isLoadingSaveInfo = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _fetchSaveInfo();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchSaveInfo() async {
    setState(() => _isLoadingSaveInfo = true);
    try {
      final results = await _pcgamingwiki.search(widget.game.name);
      if (results.isNotEmpty) {
        final saveInfo = await _pcgamingwiki.getSaveLocations(results.first.url);
        if (mounted) {
          setState(() {
            _saveInfo = saveInfo;
            _isLoadingSaveInfo = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingSaveInfo = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);

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
            // App Bar with cover
            SliverAppBar(
              expandedHeight: 350,
              pinned: true,
              backgroundColor: theme.theme.colorScheme.surface,
              leading: FocusEffectWrapper(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: widget.game.coverPath != null
                    ? Image.asset(
                        widget.game.coverPath!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
                      )
                    : _buildPlaceholder(theme),
              ),
            ),

            // Game info
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Game Title
                    Text(
                      widget.game.name,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Genres
                    if (widget.game.metadata != null &&
                        widget.game.metadata!.genres.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.game.metadata!.genres
                            .map((g) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.theme.colorScheme.primary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    g,
                                    style: TextStyle(
                                      color: theme.theme.colorScheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),

                    // Summary
                    if (widget.game.metadata?.summary != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        widget.game.metadata!.summary!,
                        style: TextStyle(
color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ],

                    // Save Game Info
                    if (_isLoadingSaveInfo)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_saveInfo != null && _saveInfo!.locations.isNotEmpty)
                      _buildSaveInfoSection(theme),

                    const SizedBox(height: 32),

                    // Launch Button
                    FocusEffectWrapper(
                      onTap: _launchGame,
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.theme.colorScheme.primary,
                              theme.theme.colorScheme.primary.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: theme.theme.colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 28, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'PLAY',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Game info cards
                    Row(
                      children: [
                        _infoCard(
                          theme,
                          icon: Icons.folder,
                          label: 'Location',
                          value: p.dirname(widget.game.exePath),
                        ),
                        const SizedBox(width: 12),
                        _infoCard(
                          theme,
                          icon: Icons.code,
                          label: 'Executable',
                          value: p.basename(widget.game.exePath),
                        ),
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

  Widget _buildPlaceholder(ThemeProvider theme) {
    return Container(
      color: theme.theme.colorScheme.surface,
      child: Center(
        child: Icon(
          Icons.gamepad_rounded,
          size: 80,
          color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  Widget _buildSaveInfoSection(ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.save,
                color: theme.theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Save Locations',
                style: TextStyle(
                  color: theme.theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_saveInfo!.cloudSync) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud, size: 12, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'Cloud Sync',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ...(_saveInfo!.locations.map((loc) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.platform,
                      style: TextStyle(
                        color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loc.path,
                      style: TextStyle(
                        color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ))),
          if (_saveInfo!.cloudServices.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Cloud: ${_saveInfo!.cloudServices.join(', ')}',
              style: TextStyle(
                color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoCard(ThemeProvider theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.theme.colorScheme.primary.withValues(alpha: 0.7), size: 18),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: theme.theme.colorScheme.onSurface.withValues(alpha: 0.8),
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
    final settings = ref.read(settingsProvider);
    final omniSave = OmniSaveService(
      savesBasePath: settings.savesPath,
    );

    await omniSave.launchGame(widget.game);

    // Update last played
    ref.read(gameLibraryProvider.notifier).updateGame(
          widget.game.copyWith(lastPlayed: DateTime.now()),
        );
  }
}
