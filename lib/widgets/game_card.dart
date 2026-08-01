import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game.dart';
import '../providers/game_library_provider.dart';
import '../providers/playing_game_provider.dart';

class GameCard extends ConsumerStatefulWidget {
  final Game game;
  final VoidCallback? onTap;

  const GameCard({
    super.key,
    required this.game,
    this.onTap,
  });

  @override
  ConsumerState<GameCard> createState() => _GameCardState();
}

class _GameCardState extends ConsumerState<GameCard> with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.035).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEnter() {
    setState(() => _hovered = true);
    _controller.forward();
  }

  void _onExit() {
    setState(() => _hovered = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // Always read the latest game from the provider (not widget.game which may be stale)
    final games = ref.watch(gameLibraryProvider).valueOrNull ?? [];
    final game = games.where((g) => g.id == widget.game.id).firstOrNull ?? widget.game;

    final accent = Theme.of(context).colorScheme.primary;
    final recentlyPlayed =
        DateTime.now().difference(game.lastPlayed).inDays < 7 &&
        game.lastPlayed.year > 2020;

    final hasCover = game.coverPath != null &&
        File(game.coverPath!).existsSync();

    // Check if this game is currently playing
    final playing = ref.watch(playingGameProvider);
    final isThisGamePlaying = playing != null && playing.game.id == game.id;

    return MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: isThisGamePlaying ? null : widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnim.value,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                  if (_hovered && !isThisGamePlaying)
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28 * _glowAnim.value),
                      blurRadius: 24,
                      spreadRadius: 1,
                    ),
                  if (isThisGamePlaying)
                    BoxShadow(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: child,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Background: cover image ──────────
                hasCover
                    ? Container(
                        key: ValueKey('cover_${game.id}_${game.lastPlayed.millisecondsSinceEpoch}'),
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: FileImage(File(game.coverPath!)),
                            fit: BoxFit.cover,
                            onError: (_, __) {},
                          ),
                        ),
                      )
                    : _Placeholder(name: game.name),

                // ── Bottom gradient (always) ─────────
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.45, 1.0],
                      colors: [Colors.transparent, Color(0xCC000000)],
                    ),
                  ),
                ),

                // ── Hover overlay ────────────────────
                if (!isThisGamePlaying)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _hovered ? 1.0 : 0.0,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.55, 1.0],
                          colors: [Colors.transparent, Color(0xDD000000)],
                        ),
                      ),
                    ),
                  ),

                // ── "Now Playing" green overlay ──────
                if (isThisGamePlaying)
                  Container(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                  ),

                // ── Hover: accent top line ───────────
                if (!isThisGamePlaying)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _hovered ? 1.0 : 0.0,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Builder(
                        builder: (ctx) => Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Theme.of(ctx).colorScheme.primary,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── "Now Playing" indicator (top) ────
                if (isThisGamePlaying)
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 12),
                              SizedBox(width: 3),
                              Text(
                                'NOW PLAYING',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Stop button
                        GestureDetector(
                          onTap: () => stopCurrentGame(ref),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.stop_rounded, color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Game name + genre ────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          game.name,
                          style: TextStyle(
                            color: isThisGamePlaying
                                ? const Color(0xFF22C55E)
                                : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 0.1,
                            shadows: const [Shadow(color: Colors.black, blurRadius: 10)],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (game.metadata?.genres.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              game.metadata!.genres.first,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Recently played green dot ────────
                if (recentlyPlayed && !isThisGamePlaying)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String name;
  const _Placeholder({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1e2040), Color(0xFF0d0f1e)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videogame_asset_rounded,
              size: 36,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.22),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
