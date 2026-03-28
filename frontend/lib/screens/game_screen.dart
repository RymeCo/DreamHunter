import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/dreamhunter_game.dart';
import 'package:dreamhunter/widgets/pause_menu_overlay.dart';
import 'package:dreamhunter/widgets/clickable_image.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final DreamHunterGame _game;

  @override
  void initState() {
    super.initState();
    _game = DreamHunterGame(characterType: 'man');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Stack(
        children: [
          GameWidget(
            game: _game,
            overlayBuilderMap: {
              'PauseMenu': (context, DreamHunterGame game) => PauseMenuOverlay(game: game),
            },
            loadingBuilder: (context) => const Center(
              child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: GlassButton(
              label: 'II',
              width: 50,
              height: 50,
              borderRadius: 12,
              glowColor: Colors.white70,
              pulseMinOpacity: 0.6,
              onTap: () {
                if (!_game.overlays.isActive('PauseMenu')) {
                  _game.pauseEngine();
                  _game.overlays.add('PauseMenu');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
