import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'actors/player.dart';
import 'level/level.dart';
import 'objects/building_slot.dart';
import 'objects/turret.dart';
import 'objects/generator.dart';

class HauntedDormGame extends FlameGame
    with HasCollisionDetection, TapCallbacks {
  final String characterType;
  late final JoystickComponent joystick;
  late final Player player;
  late final Level level;

  // Track the currently selected building slot or turret
  BuildingSlot? activeSlot;
  Turret? activeTurret;

  // Track if the monster is allowed to move
  bool isGracePeriod = true;

  // Track all hunters (1 player + 7 AI)
  final List<Component> hunters = [];

  HauntedDormGame({required this.characterType});

  void buildTurret() {
    if (activeSlot == null || activeSlot!.isOccupied) return;

    final turret = Turret(
      position: activeSlot!.position.clone(),
      size: activeSlot!.size.clone(),
      level: 1,
    );

    level.add(turret);
    activeSlot!.isOccupied = true;
    player.energy -= 10; 
    activeSlot = null;
  }

  void buildGenerator(int levelNum) {
    if (activeSlot == null || activeSlot!.isOccupied) return;

    final generator = Generator(
      position: activeSlot!.position.clone(),
      size: activeSlot!.size.clone(),
      level: levelNum,
    );

    level.add(generator);
    activeSlot!.isOccupied = true;
    player.energy -= (levelNum * 50); 
    activeSlot = null;
  }

  @override
  Future<void> onLoad() async {
    _addJoystick();

    player = Player(joystick: joystick, characterType: characterType);
    level = Level(levelName: 'dorm-01', player: player);

    camera = CameraComponent.withFixedResolution(
      world: level,
      width: size.x,
      height: size.y,
    );
    camera.follow(player);
    camera.viewfinder.anchor = Anchor.center;

    // Initial HUD & Overlays
    camera.viewport.add(joystick);
    overlays.add('GraceTimer');

    addAll([camera, level]);
  }

  void _addJoystick() {
    final knobPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.3)
      ..style = PaintingStyle.fill;

    final backgroundPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.05)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.15)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    joystick = JoystickComponent(
      knob: CircleComponent(
        radius: 25,
        paint: knobPaint,
        children: [CircleComponent(radius: 25, paint: borderPaint)],
      ),
      background: CircleComponent(
        radius: 60,
        paint: backgroundPaint,
        children: [CircleComponent(radius: 60, paint: borderPaint)],
      ),
      margin: const EdgeInsets.only(left: 40, bottom: 40),
    );
  }

  @override
  Color backgroundColor() => const Color(0xFF111111);
}
