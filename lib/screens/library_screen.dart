import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import '../models/game.dart';
import '../providers/game_library_provider.dart';
import '../providers/search_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/ui_provider.dart';
import '../services/platform_service.dart';
import '../services/game_launch_service.dart';
import '../widgets/art_picker_dialog.dart';
import '../widgets/game_grid.dart';
import '../widgets/focus_effect_wrapper.dart';
import '../widgets/metadata_editor_dialog.dart';
import '../widgets/save_location_dialog.dart';
import '../widgets/screenshot_viewer.dart';
import 'game_detail_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late FocusNode _focusNode;
  bool _isListView = false;
  Game? _selectedGame;
  bool _searchOpen = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _isListView = Hive.box('settings').get('isListView', defaultValue: false) as bool;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (_searchOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      } else {
        _searchController.clear();
        ref.read(searchQueryProvider.notifier).state = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gamesAsync = ref.watch(searchResultsProvider);
    final theme = ref.watch(themeProvider);
    final inputMode = ref.watch(inputModeProvider);
    final cs = theme.theme.colorScheme;
    final searchQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.f5) {
              ref.read(gameLibraryProvider.notifier).rescan();
            } else if (event.logicalKey == LogicalKeyboardKey.escape && _searchOpen) {
              _toggleSearch();
            }
          }
        },
        child: Row(
          children: [
            // ── Sidebar ──────────────────────────────────────────────────
            _Sidebar(
              gameCount: ref.read(gameLibraryProvider).valueOrNull?.length,
              isListView: _isListView,
              onToggleView: (listView) {
                setState(() {
                  _isListView = listView;
                  if (!listView) _selectedGame = null;
                });
                Hive.box('settings').put('isListView', listView);
              },
              onRescan: () => ref.read(gameLibraryProvider.notifier).rescan(),
              onSettings: () => Navigator.of(context).pushNamed('/settings'),
              onSearch: _toggleSearch,
              searchActive: _searchOpen,
            ),

            // ── Divider ──────────────────────────────────────────────────
            VerticalDivider(
              width: 1,
              color: cs.outline.withValues(alpha: 0.12),
            ),

            // ── Main content ─────────────────────────────────────────────
            Expanded(
              child: Column(
                children: [
                  // ── Sliding search bar ────────────────────────────────
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: _searchOpen
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              border: Border(
                                bottom: BorderSide(
                                  color: cs.outline.withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 14,
                                    ),
                                    onChanged: (val) {
                                      ref.read(searchQueryProvider.notifier).state = val;
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Search games by name, genre, developer...',
                                      hintStyle: TextStyle(
                                        color: cs.onSurface.withValues(alpha: 0.35),
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                if (searchQuery.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      ref.read(searchQueryProvider.notifier).state = '';
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: cs.onSurface.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: cs.onSurface.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _toggleSearch,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: cs.onSurface.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.keyboard_hide_rounded,
                                      size: 16,
                                      color: cs.onSurface.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // ── Games content ────────────────────────────────────
                  Expanded(
                    child: gamesAsync.when(
                      loading: () => Center(
                        child: CircularProgressIndicator(
                          color: cs.primary,
                          strokeWidth: 2,
                        ),
                      ),
                      error: (error, _) => _ErrorState(
                        error: error.toString(),
                        onRetry: () => ref.read(gameLibraryProvider.notifier).rescan(),
                      ),
                      data: (games) {
                        if (games.isEmpty) {
                          if (searchQuery.isNotEmpty) {
                            return _NoSearchResults(query: searchQuery);
                          }
                          return _EmptyState(
                            onRescan: () => ref.read(gameLibraryProvider.notifier).rescan(),
                          );
                        }
                        if (_isListView) {
                          // Auto-select first game if none selected
                          final selected = _selectedGame != null
                              ? games.firstWhere(
                                  (g) => g.id == _selectedGame!.id,
                                  orElse: () => games.first,
                                )
                              : games.first;
                          return _ListDetailView(
                            games: games,
                            selectedGame: selected,
                            onSelectGame: (g) => setState(() => _selectedGame = g),
                          );
                        }
                        return GameGrid(games: games);
                      },
                    ),
                  ),
                  if (inputMode == InputMode.gamepad)
                    ControllerHintsBar(inputMode: inputMode),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sidebar ──────────────────────────────────────────────────────────────────

class _Sidebar extends ConsumerWidget {
  final int? gameCount;
  final bool isListView;
  final ValueChanged<bool> onToggleView;
  final VoidCallback onRescan;
  final VoidCallback onSettings;
  final VoidCallback onSearch;
  final bool searchActive;

  const _Sidebar({
    required this.gameCount,
    required this.isListView,
    required this.onToggleView,
    required this.onRescan,
    required this.onSettings,
    required this.onSearch,
    required this.searchActive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final cs = theme.theme.colorScheme;
    final bg = cs.surface;

    return Container(
      width: 72,
      color: bg,
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Logo icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cs.primary, cs.primary.withValues(alpha: 0.6)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.diamond_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            'INDIE',
            style: TextStyle(
              color: cs.primary,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 20),

          // Search button
          Tooltip(
            message: 'Search',
            preferBelow: false,
            child: _SidebarIconButton(
              icon: Icons.search_rounded,
              tooltip: 'Search',
              onTap: onSearch,
              active: searchActive,
            ),
          ),
          const SizedBox(height: 8),

          // Game count badge
          if (gameCount != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$gameCount',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              'games',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.35),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // View toggle — Grid
          Tooltip(
            message: 'Grid view',
            preferBelow: false,
            child: _ViewToggleButton(
              icon: Icons.grid_view_rounded,
              active: !isListView,
              onTap: () => onToggleView(false),
            ),
          ),
          const SizedBox(height: 4),
          // View toggle — List+Detail
          Tooltip(
            message: 'List view',
            preferBelow: false,
            child: _ViewToggleButton(
              icon: Icons.view_sidebar_rounded,
              active: isListView,
              onTap: () => onToggleView(true),
            ),
          ),

          const Spacer(),

          // Rescan button
          _SidebarIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Rescan (F5)',
            onTap: onRescan,
          ),
          const SizedBox(height: 8),

          // Settings button
          _SidebarIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Settings',
            onTap: onSettings,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ViewToggleButton extends ConsumerStatefulWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ViewToggleButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  ConsumerState<_ViewToggleButton> createState() => _ViewToggleButtonState();
}

class _ViewToggleButtonState extends ConsumerState<_ViewToggleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = ref.watch(themeProvider).theme.colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: widget.active
                ? cs.primary.withValues(alpha: 0.18)
                : _hovered
                    ? cs.primary.withValues(alpha: 0.09)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: widget.active
                ? Border.all(color: cs.primary.withValues(alpha: 0.4), width: 1)
                : null,
          ),
          child: Icon(
            widget.icon,
            color: widget.active
                ? cs.primary
                : _hovered
                    ? cs.onSurface.withValues(alpha: 0.7)
                    : cs.onSurface.withValues(alpha: 0.35),
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _SidebarIconButton extends ConsumerStatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  const _SidebarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  ConsumerState<_SidebarIconButton> createState() => _SidebarIconButtonState();
}

class _SidebarIconButtonState extends ConsumerState<_SidebarIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = ref.watch(themeProvider).theme.colorScheme;
    final isActive = widget.active;
    return Tooltip(
      message: widget.tooltip,
      preferBelow: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive
                  ? cs.primary.withValues(alpha: 0.18)
                  : _hovered
                      ? cs.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? Border.all(color: cs.primary.withValues(alpha: 0.4), width: 1)
                  : null,
            ),
            child: Icon(
              widget.icon,
              color: isActive
                  ? cs.primary
                  : _hovered
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.45),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ── List + Detail View ────────────────────────────────────────────────────────

class _ListDetailView extends ConsumerWidget {
  final List<Game> games;
  final Game selectedGame;
  final ValueChanged<Game> onSelectGame;

  const _ListDetailView({
    required this.games,
    required this.selectedGame,
    required this.onSelectGame,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = ref.watch(themeProvider).theme.colorScheme;

    return Row(
      children: [
        // ── Left: game list ────────────────────────────────────────────
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              right: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
            ),
          ),
          child: Column(
            children: [
              // List header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Text(
                      'LIBRARY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: cs.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${games.length}',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.primary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outline.withValues(alpha: 0.1)),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: games.length,
                  itemBuilder: (ctx, i) {
                    final game = games[i];
                    final isSelected = game.id == selectedGame.id;
                    return _GameListRow(
                      game: game,
                      isSelected: isSelected,
                      onTap: () => onSelectGame(game),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // ── Right: detail panel ────────────────────────────────────────
        Expanded(
          child: _GameDetailPanel(
            key: ValueKey(selectedGame.id),
            game: selectedGame,
          ),
        ),
      ],
    );
  }
}

class _GameListRow extends ConsumerStatefulWidget {
  final Game game;
  final bool isSelected;
  final VoidCallback onTap;

  const _GameListRow({
    required this.game,
    required this.isSelected,
    required this.onTap,
  });

  @override
  ConsumerState<_GameListRow> createState() => _GameListRowState();
}

class _GameListRowState extends ConsumerState<_GameListRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = ref.watch(themeProvider).theme.colorScheme;
    final recentlyPlayed = DateTime.now()
            .difference(widget.game.lastPlayed)
            .inDays <
        7;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? cs.primary.withValues(alpha: 0.15)
                : _hovered
                    ? cs.primary.withValues(alpha: 0.07)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: widget.isSelected
                ? Border.all(color: cs.primary.withValues(alpha: 0.3), width: 1)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox(
                    width: 40,
                    height: 54,
                    child: widget.game.coverPath != null
                        ? Image.file(
                            File(widget.game.coverPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildThumbPlaceholder(cs),
                          )
                        : _buildThumbPlaceholder(cs),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.game.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: widget.isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: widget.isSelected
                              ? cs.onSurface
                              : cs.onSurface.withValues(alpha: 0.85),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.game.metadata?.genres.isNotEmpty == true) ...[
                        const SizedBox(height: 3),
                        Text(
                          widget.game.metadata!.genres.first,
                          style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurface.withValues(alpha: 0.4),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Recently played indicator
                if (recentlyPlayed)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbPlaceholder(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Icon(
        Icons.videogame_asset_rounded,
        size: 18,
        color: cs.onSurface.withValues(alpha: 0.15),
      ),
    );
  }
}

// ── In-place Game Detail Panel ────────────────────────────────────────────────

class _GameDetailPanel extends ConsumerStatefulWidget {
  final Game game;

  const _GameDetailPanel({super.key, required this.game});

  @override
  ConsumerState<_GameDetailPanel> createState() => _GameDetailPanelState();
}

class _GameDetailPanelState extends ConsumerState<_GameDetailPanel> {
  bool _isLaunching = false;
  String _launchStatus = '';
  GameLaunchService? _launchService;

  Future<void> _launchGame(Game game) async {
    if (_isLaunching) return;
    setState(() {
      _isLaunching = true;
      _launchStatus = 'Preparing...';
    });

    // Check if omnisave is configured — if not, open game detail so user can set it up
    final metaFile = File(p.join(game.folderPath, '.indie', 'meta.json'));
    bool omnisaveConfigured = false;
    if (await metaFile.exists()) {
      try {
        final meta = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        omnisaveConfigured = meta['omnisaveConfigured'] == true;
      } catch (_) {}
    }

    if (!omnisaveConfigured) {
      // First launch — navigate to detail screen so user can configure save location
      if (mounted) {
        setState(() => _isLaunching = false);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GameDetailScreen(game: game)),
        );
      }
      return;
    }

    // Use the launch service for full lifecycle management
    _launchService = GameLaunchService();
    await _launchService!.launch(
      game,
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

    // If launch completed (OmniSave path), ensure state is reset
    if (mounted) {
      setState(() {
        _isLaunching = false;
        _launchStatus = '';
      });
    }
  }

  Future<void> _confirmOpenVideo(String title, String url) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Video'),
        content: Text('"$title" will open in your default browser.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.open_in_browser, size: 16),
            label: const Text('Open in Browser'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      PlatformService.openUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read live data from provider so art updates are reflected
    final liveGame = ref.watch(gameLibraryProvider).valueOrNull
            ?.firstWhere((g) => g.id == widget.game.id, orElse: () => widget.game) ??
        widget.game;

    final cs = ref.watch(themeProvider).theme.colorScheme;
    final meta = liveGame.metadata;
    final hasBanner = liveGame.bannerPath != null;
    final hasCover = liveGame.coverPath != null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner ──────────────────────────────────────────────────
          Stack(
            children: [
              // Banner image
              SizedBox(
                height: 200,
                width: double.infinity,
                child: hasBanner
                    ? Image.file(
                        File(liveGame.bannerPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _bannerPlaceholder(cs),
                      )
                    : hasCover
                        ? Image.file(
                            File(liveGame.coverPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _bannerPlaceholder(cs),
                          )
                        : _bannerPlaceholder(cs),
              ),
              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.2, 1.0],
                      colors: [
                        Colors.transparent,
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Cover + Title row overlapping the banner ──────────────────
          Transform.translate(
            offset: const Offset(0, -40),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Cover art floating up
                  if (hasCover)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Image.file(
                          File(liveGame.coverPath!),
                          width: 100,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      ),
                    ),
                  if (hasCover) const SizedBox(width: 18),

                  // Title + meta
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: hasCover ? 4 : 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            liveGame.name,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (meta != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              [
                                if (meta.developer != null) meta.developer!,
                                if (meta.releaseDate != null) meta.releaseDate!,
                              ].join('  ·  '),
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                          if (meta?.genres.isNotEmpty == true) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 5,
                              runSpacing: 4,
                              children: meta!.genres
                                  .take(3)
                                  .map((g) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 9, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: cs.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          g,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: cs.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],
                          if (meta?.rating != null) ...[
                            const SizedBox(height: 8),
                            _ratingRow(meta!.rating!, cs),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content below banner overlap ──────────────────────────────
          Transform.translate(
            offset: const Offset(0, -30),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PLAY button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLaunching ? null : () => _launchGame(liveGame),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: _isLaunching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 26),
                      label: Text(
                        _isLaunching
                            ? (_launchStatus.isNotEmpty ? _launchStatus.toUpperCase() : 'LAUNCHING...')
                            : 'PLAY',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Secondary action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => SaveLocationDialog(game: liveGame),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.onSurface.withValues(alpha: 0.7),
                            side: BorderSide(
                                color: cs.outline.withValues(alpha: 0.2)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.folder_open, size: 15),
                          label: const Text('Save Location',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),

                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => ArtPickerDialog(game: liveGame),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.onSurface.withValues(alpha: 0.7),
                            side: BorderSide(
                                color: cs.outline.withValues(alpha: 0.2)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.image_search, size: 15),
                          label: const Text('Metadata',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Edit metadata button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => MetadataEditorDialog(game: liveGame),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.onSurface.withValues(alpha: 0.7),
                        side: BorderSide(
                            color: cs.outline.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.edit_note_rounded, size: 15),
                      label: const Text('Edit Metadata',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),

                  // ── Summary ──────────────────────────────────────────
                  if (meta?.summary != null) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('ABOUT', cs),
                    const SizedBox(height: 8),
                    Text(
                      meta!.summary!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.65,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // ── Screenshots strip ────────────────────────────────
                  if (meta != null && meta.screenshots.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('SCREENSHOTS', cs),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: meta.screenshots.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  File(path),
                                  width: 180,
                                  height: 110,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 180,
                                    height: 110,
                                    color: cs.surfaceContainerHighest,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // ── Videos strip ─────────────────────────────────────
                  if (meta != null && meta.videos.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('VIDEOS', cs),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: meta.videos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final v = meta.videos[i];
                          return GestureDetector(
                            onTap: () => _confirmOpenVideo(v.name, v.youtubeUrl),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    v.thumbnailUrl,
                                    height: 100,
                                    width: 170,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 170,
                                      height: 100,
                                      color: cs.surfaceContainerHighest,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded,
                                      color: Colors.white, size: 22),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerPlaceholder(ColorScheme cs) {
    return Container(
      color: cs.surface,
      child: Center(
        child: Icon(
          Icons.videogame_asset_rounded,
          size: 56,
          color: cs.onSurface.withValues(alpha: 0.1),
        ),
      ),
    );
  }

  Widget _ratingRow(double rating, ColorScheme cs) {
    final stars = (rating / 20).clamp(0.0, 5.0);
    final full = stars.floor();
    final half = (stars - full) >= 0.5;
    return Row(
      children: [
        ...List.generate(5, (i) {
          if (i < full) {
            return Icon(Icons.star_rounded, size: 15, color: cs.primary);
          } else if (i == full && half) {
            return Icon(Icons.star_half_rounded, size: 15, color: cs.primary);
          }
          return Icon(Icons.star_outline_rounded,
              size: 15, color: cs.primary.withValues(alpha: 0.3));
        }),
        const SizedBox(width: 5),
        Text(
          '${rating.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label, ColorScheme cs) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: cs.primary.withValues(alpha: 0.8),
      ),
    );
  }
}

// ── States ───────────────────────────────────────────────────────────────────

class _EmptyState extends ConsumerWidget {
  final VoidCallback onRescan;
  const _EmptyState({required this.onRescan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = ref.watch(themeProvider).theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_rounded, size: 72, color: cs.onSurface.withValues(alpha: 0.12)),
          const SizedBox(height: 20),
          Text('No games found',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.55))),
          const SizedBox(height: 8),
          Text('Add game folders to the Games directory',
              style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.35))),
          const SizedBox(height: 28),
          _PillButton(label: 'Scan Again', icon: Icons.refresh_rounded, onTap: onRescan),
        ],
      ),
    );
  }
}

class _ErrorState extends ConsumerWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = ref.watch(themeProvider).theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 56, color: cs.error.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
          Text('Error loading games',
              style: TextStyle(fontSize: 18, color: cs.onSurface.withValues(alpha: 0.8))),
          const SizedBox(height: 8),
          Text(error, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 24),
          _PillButton(label: 'Retry', icon: Icons.refresh_rounded, onTap: onRetry),
        ],
      ),
    );
  }
}

class _PillButton extends ConsumerStatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PillButton({required this.label, required this.icon, required this.onTap});

  @override
  ConsumerState<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends ConsumerState<_PillButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = ref.watch(themeProvider).theme.colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            color: _hovered ? cs.primary : cs.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: _hovered ? Colors.white : cs.primary),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: _hovered ? Colors.white : cs.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── No search results ────────────────────────────────────────────────────────

class _NoSearchResults extends ConsumerWidget {
  final String query;
  const _NoSearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = ref.watch(themeProvider).theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: cs.onSurface.withValues(alpha: 0.12)),
          const SizedBox(height: 16),
          Text(
            'No results for "$query"',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
