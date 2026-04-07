import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import '../haunted_dorm_game.dart';
import '../actors/player.dart';
import 'package:dreamhunter/services/audio_service.dart';

class HUD extends PositionComponent with HasGameReference<HauntedDormGame> {
  late TextComponent energyText;
  late TextComponent coinText;
  late ButtonComponent sleepButton;
  late ButtonComponent exitButton;

  HUD() : super(priority: 10);

  @override
  Future<void> onLoad() async {
    final regular = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        backgroundColor: Colors.black38,
      ),
    );

    energyText = TextComponent(
      text: 'Energy: 0',
      position: Vector2(20, 20),
      textRenderer: regular,
    );
    add(energyText);

    coinText = TextComponent(
      text: 'Coins: 0',
      position: Vector2(20, 50),
      textRenderer: regular,
    );
    add(coinText);

    final buttonPaint = Paint()
      ..color = Colors.deepPurpleAccent.withValues(alpha: 0.5);
    final buttonText = TextPaint(
      style: const TextStyle(color: Colors.white, fontSize: 14),
    );

    sleepButton = ButtonComponent(
      button: RectangleComponent(size: Vector2(80, 40), paint: buttonPaint),
      children: [
        TextComponent(
          text: 'SLEEP',
          textRenderer: buttonText,
          anchor: Anchor.center,
          position: Vector2(40, 20),
        ),
      ],
      position: Vector2(game.size.x - 100, game.size.y - 100),
      onPressed: () {
        AudioService().playClick();
        game.player.enterBed();
      },
    );

    exitButton = ButtonComponent(
      button: RectangleComponent(size: Vector2(80, 40), paint: buttonPaint),
      children: [
        TextComponent(
          text: 'EXIT',
          textRenderer: buttonText,
          anchor: Anchor.center,
          position: Vector2(40, 20),
        ),
      ],
      position: Vector2(game.size.x - 100, game.size.y - 100),
      onPressed: () {
        AudioService().playClick();
        game.player.exitBed();
      },
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    energyText.text = 'Energy: ${game.player.energy.toInt()}';
    coinText.text = 'Coins: ${game.player.energy.toInt()}'; // Temporary link to energy until economy ticks are built

    final isSleeping = game.player.state == PlayerState.sleeping;

    if (isSleeping) {
      if (!exitButton.isMounted) add(exitButton);
    } else {
      if (exitButton.isMounted) remove(exitButton);
    }
  }
}
