import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../game/dreamhunter_game.dart';
import 'package:dreamhunter/game/pause_menu_overlay.dart';
import 'package:dreamhunter/widgets/glass_button.dart';

class GameScreen extends StatefulWidget {
  final String characterType;
  const GameScreen({super.key, required this.characterType});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late DreamHunterGame _game;

  @override
  void initState() {
    super.initState();
    _game = DreamHunterGame(characterType: widget.characterType);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // THE GAME VIEW WITH OVERLAYS
          Positioned.fill(
            child: GameWidget(
              game: _game,
              overlayBuilderMap: {
                'PauseMenu': (context, DreamHunterGame game) =>
                    PauseMenuOverlay(game: game),
              },
            ),
          ),

          // PAUSE TRIGGER BUTTON
          Positioned(
            top: 50,
            right: 20,
            child: GlassButton(
              width: 56,
              height: 56,
              borderRadius: 14,
              glowColor: Colors.white,
              onTap: () {
                if (!_game.overlays.isActive('PauseMenu')) {
                  _game.pauseEngine();
                  _game.overlays.add('PauseMenu');
                }
              },
              child: const Icon(
                Icons.pause_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
