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

    // Update global grace state for actors
    isGracePeriod = gameState.status == GameStatus.grace;
  }

  @override
  FutureOr<void> onLoad() async {
    _addJoystick();

    player = Player(joystick: joystick, characterType: characterType);
    level = Level(levelName: 'dorm-01', player: player);

    // CAMERA: exactly 7 tiles wide (224px) for perfect scaling
    camera = CameraComponent(world: level);
    camera.viewfinder.zoom = 1.0;

    camera.viewport.add(
      RectangleComponent(
        size: camera.viewport.size,
        paint: Paint()..color = const Color(0x084B0082),
      ),
    );

    camera.viewport.add(joystick);
    addAll([level, camera]);

    camera.follow(player);
    return super.onLoad();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      camera.viewfinder.zoom = size.x / 224;
    }
  }

  void _addJoystick() {
    // LiquidGlass Joystick style - SCALED UP
    final knobPaint = Paint()..color = const Color.fromRGBO(255, 255, 255, 0.4);
    final backgroundPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.1);
    final borderPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    joystick = JoystickComponent(
      knob: CircleComponent(
        radius: 35, // Increased from 20
        paint: knobPaint,
        children: [CircleComponent(radius: 35, paint: borderPaint)],
      ),
      background: CircleComponent(
        radius: 75, // Increased from 40
        paint: backgroundPaint,
        children: [CircleComponent(radius: 75, paint: borderPaint)],
      ),
      margin: const EdgeInsets.only(left: 50, bottom: 50),
    );
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
    if (activeSlot != null && player.coins >= 50) {
      player.coins -= 50;
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
