import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game.dart';

import '../screens/game_detail_screen.dart';
import '../screens/metadata_picker.dart';
import 'game_card.dart';
import 'focus_effect_wrapper.dart';

class GameGrid extends ConsumerWidget {
  final List<Game> games;

  const GameGrid({super.key, required this.games});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        double childAspectRatio;

        if (constraints.maxWidth > 1200) {
          crossAxisCount = 5;
          childAspectRatio = 0.65;
        } else if (constraints.maxWidth > 900) {
          crossAxisCount = 4;
          childAspectRatio = 0.7;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
          childAspectRatio = 0.75;
        } else {
          crossAxisCount = 2;
          childAspectRatio = 0.8;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index];
            return FocusEffectWrapper(
              key: ValueKey('${game.id}_${game.lastPlayed.millisecondsSinceEpoch}'),
              onTap: () => _openGameDetail(context, game),
              onLongPress: () => _openMetadataPicker(context, game),
              child: GameCard(game: game),
            );
          },
        );
      },
    );
  }

  void _openGameDetail(BuildContext context, Game game) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameDetailScreen(game: game),
      ),
    );
  }

  void _openMetadataPicker(BuildContext context, Game game) {
    showDialog(
      context: context,
      builder: (_) => MetadataPicker(game: game),
    );
  }
}
