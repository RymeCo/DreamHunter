import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/dreamhunter_game.dart';
import 'package:dreamhunter/game/actors/player.dart';

class HUD extends PositionComponent with HasGameReference<DreamHunterGame> {
  late TextComponent energyText;
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
      onPressed: () => game.player.enterBed(),
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
      onPressed: () => game.player.exitBed(),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    energyText.text = 'Energy: ${game.player.energy.toInt()}';

    final isSleeping = game.player.state == PlayerState.sleeping;
    final isNearBed = game.player.isNearBed;

    if (isSleeping) {
      if (!exitButton.isMounted) add(exitButton);
      if (sleepButton.isMounted) remove(sleepButton);
    } else if (isNearBed) {
      if (!sleepButton.isMounted) add(sleepButton);
      if (exitButton.isMounted) remove(exitButton);
    } else {
      if (sleepButton.isMounted) remove(sleepButton);
      if (exitButton.isMounted) remove(exitButton);
    }
  }
}
