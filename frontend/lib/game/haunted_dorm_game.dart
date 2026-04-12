import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'actors/player.dart';
import 'level/level.dart';
import 'actors/ai_hunter.dart';
import 'objects/turret.dart';
import 'objects/generator.dart';
import 'objects/building_slot.dart';
import 'core/game_state_manager.dart';

class HauntedDormGame extends FlameGame
    with HasCollisionDetection, KeyboardEvents {
  final String characterType;
  late final Player player;
  late final Level level;
  late final JoystickComponent joystick;
  late final GameStateManager gameState;

  final List<AIHunter> hunters = [];
  bool isGracePeriod = true;
  static const double matchDuration = 900;

  BuildingSlot? activeSlot;
  Turret? activeTurret;

  HauntedDormGame({required this.characterType}) {
    gameState = GameStateManager(duration: matchDuration);
    gameState.addListener(_onGameStateChanged);
  }

  void _onGameStateChanged() {
    if (gameState.status == GameStatus.gameOver ||
        gameState.status == GameStatus.victory) {
      endGame(victory: gameState.status == GameStatus.victory);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    gameState.updateTimer(dt);
  }

  @override
  FutureOr<void> onLoad() async {
    _addJoystick();

    // CAMERA FIX: Exactly 7 tiles wide (224px) and 15 tiles high (480px)
    camera = CameraComponent.withFixedResolution(width: 224, height: 480);

    camera.viewport.add(
      RectangleComponent(
        size: Vector2(224, 480),
        paint: Paint()..color = const Color(0x084B0082),
      ),
    );

    player = Player(joystick: joystick, characterType: characterType);
    level = Level(levelName: 'dorm-01', player: player);

    add(level);
    add(camera);

    camera.follow(player);
    return super.onLoad();
  }

  void _addJoystick() {
    final knobPaint = Paint()..color = const Color.fromRGBO(255, 255, 255, 0.3);
    final backgroundPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.05);

    joystick = JoystickComponent(
      knob: CircleComponent(radius: 20, paint: knobPaint),
      background: CircleComponent(radius: 40, paint: backgroundPaint),
      margin: const EdgeInsets.only(left: 40, bottom: 40),
    );
    camera.viewport.add(joystick);
  }

  void buildTurret() {
    if (activeSlot != null && player.energy >= 10) {
      player.energy -= 10;
      final turret = Turret(
        position: activeSlot!.position.clone(),
        size: activeSlot!.size.clone(),
      );
      level.add(turret);
      activeSlot!.isOccupied = true;
      overlays.remove('BuildMenu');
    }
  }

  void buildGenerator(int levelNum) {
    if (activeSlot != null && player.energy >= 50) {
      player.energy -= 50;
      final gen = Generator(
        position: activeSlot!.position.clone(),
        size: activeSlot!.size.clone(),
        level: levelNum,
      );
      level.add(gen);
      activeSlot!.isOccupied = true;
      overlays.remove('BuildMenu');
    }
  }

  void endGame({required bool victory}) {
    overlays.add('GameOver');
    pauseEngine();
  }
}
