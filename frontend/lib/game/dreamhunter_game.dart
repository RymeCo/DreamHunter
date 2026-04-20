import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// A simplified placeholder for the DreamHunter game loop.
/// Currently only handles basic initialization and asset cleanup.
class DreamHunterGame extends FlameGame {
  final String characterType;

  DreamHunterGame({required this.characterType});

  @override
  Future<void> onLoad() async {
    // Game logic removed for now as per requirements.
    // Assets are pre-loaded in the loading screen.
    debugPrint('DreamHunterGame: Placeholder loaded for $characterType');
  }

  void disposeGame() {
    pauseEngine();
    world.removeAll(world.children);
  }

  @override
  Color backgroundColor() => const Color(0xFF111111);
}
