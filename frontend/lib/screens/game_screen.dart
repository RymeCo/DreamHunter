import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/dreamhunter_game.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: GameWidget(
        game: DreamHunterGame(characterType: 'man'),
        loadingBuilder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      ),
    );
  }
}
