import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'actors/player.dart';
import 'level/level.dart';

class DreamHunterGame extends FlameGame with HasCollisionDetection, TapCallbacks {
  final String characterType;
  late final JoystickComponent joystick;
  late final Player player;
  late final Level level;

  DreamHunterGame({required this.characterType});

  @override
  Future<void> onLoad() async {
    _addJoystick();

    player = Player(joystick: joystick, characterType: characterType);

    level = Level(levelName: 'mini-01', player: player);

    camera = CameraComponent.withFixedResolution(
      world: level,
      width: 400,
      height: 800,
    );
    camera.follow(player);

    camera.viewport.add(joystick);

    addAll([camera, level]);
  }

  void _addJoystick() {
    final knobPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.4)
      ..style = PaintingStyle.fill;
    
    final backgroundPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.1)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.2)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    joystick = JoystickComponent(
      knob: CircleComponent(
        radius: 25, 
        paint: knobPaint,
        children: [
          CircleComponent(
            radius: 25,
            paint: borderPaint,
          ),
        ],
      ),
      background: CircleComponent(
        radius: 60, 
        paint: backgroundPaint,
        children: [
          CircleComponent(
            radius: 60,
            paint: borderPaint,
          ),
        ],
      ),
      margin: const EdgeInsets.only(left: 40, bottom: 40),
    );
  }

  @override
  Color backgroundColor() => const Color(0xFF1A1A1A);
}
