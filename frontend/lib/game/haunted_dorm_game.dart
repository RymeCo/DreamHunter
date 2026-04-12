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

    player = Player(joystick: joystick, characterType: characterType);
    level = Level(levelName: 'dorm-01', player: player);

    // Use default CameraComponent (MaxViewport) for true full-screen
    camera = CameraComponent(world: level);

    // Set a responsive zoom: Target ~10-12 tiles (320-384px) visible horizontally.
    // We'll set a base zoom and allow it to scale in onGameResize.
    camera.viewfinder.zoom = 1.0;

    // Add a subtle full-screen tint to the viewport
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
    // Responsive Scaling: Ensure we always see roughly the same amount of game world
    // by adjusting zoom based on the current screen width.
    if (isLoaded) {
      camera.viewfinder.zoom = (size.x / 360).clamp(1.0, 3.0);
    }
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
