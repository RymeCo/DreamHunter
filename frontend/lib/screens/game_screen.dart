import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../game/haunted_dorm_game.dart';
import '../widgets/game_economy_hud.dart';
import '../widgets/build_menu.dart';
import '../widgets/upgrade_menu.dart';

class GameScreen extends StatefulWidget {
  final String characterType;
  const GameScreen({super.key, required this.characterType});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late HauntedDormGame _game;

  @override
  void initState() {
    super.initState();
    _game = HauntedDormGame(characterType: widget.characterType);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GameWidget(
            game: _game,
            overlayBuilderMap: {
              'BuildMenu': (context, HauntedDormGame game) =>
                  BuildMenu(game: game),
              'UpgradeMenu': (context, HauntedDormGame game) =>
                  UpgradeMenu(game: game),
              'GameOver': (context, HauntedDormGame game) => Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent, width: 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'GAME OVER',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('BACK TO DASHBOARD'),
                      ),
                    ],
                  ),
                ),
              ),
            },
          ),

          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                ListenableBuilder(
                  listenable: _game.gameState,
                  builder: (context, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        _game.gameState.formattedTime,
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'TIME REMAINING',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // ECONOMY HUD
          GameEconomyHUD(game: _game),
        ],
      ),
    );
  }
}
