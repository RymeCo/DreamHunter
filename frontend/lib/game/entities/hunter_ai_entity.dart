import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/behaviors/hunter_movement_behavior.dart';
import 'package:dreamhunter/game/behaviors/ai_build_behavior.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/entities/bed_entity.dart';
import 'package:dreamhunter/game/entities/door_entity.dart';
import 'package:dreamhunter/game/entities/fridge_entity.dart';
import 'package:dreamhunter/services/game/match_manager.dart';

enum AIPersonality { defense, offense, randos }

enum AISpeed { fast, slow }

/// An AI-controlled hunter entity.
class HunterAIEntity extends BaseEntity {
  final String skinPath;
  BedEntity targetBed;
  late final SpriteComponent _spriteComponent;
  late final Sprite _sleepingSprite;
  late final TextComponent _walletLabel;

  final AIPersonality personality;
  final AISpeed speed;

  int repathCount = 0;

  HunterAIEntity({
    required this.skinPath,
    required this.targetBed,
    super.position,
  }) : personality = AIPersonality
           .values[math.Random().nextInt(AIPersonality.values.length)],
       speed = AISpeed.values[math.Random().nextInt(AISpeed.values.length)],
       super(
         size: Vector2(32, 48), // Standard character size
         anchor: Anchor.bottomCenter,
       ) {
    addCategory('ai_hunter');
    maxHp = 1.0;
    hp = maxHp;
  }

  @override
  String get roomID => targetBed.roomID;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load the sprite
    final imagePath = skinPath.replaceFirst('assets/images/', '');
    final sprite = await Sprite.load(imagePath);

    // Create cropped sleeping head sprite
    _sleepingSprite = Sprite(
      sprite.image,
      srcPosition: sprite.srcPosition,
      srcSize: Vector2(32, 24),
    );

    _spriteComponent = SpriteComponent(sprite: sprite, size: size);

    add(_spriteComponent);

    // Initialize wallet label (hidden by default)
    _walletLabel = TextComponent(
      text: '',
      anchor: Anchor.bottomCenter,
      position: Vector2(size.x / 2, -4),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.amberAccent,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      ),
    );

    // Add behaviors
    add(HunterMovementBehavior());
    add(AIBuildBehavior());
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update wallet display if sleeping
    if (isSleeping) {
      _walletLabel.text = '$matchCoins';
      if (_walletLabel.parent == null) {
        add(_walletLabel);
      }

      // NEW: AI Repair Behavior
      _handleAIRepairs();
    }
  }

  void _handleAIRepairs() {
    final myRoom = roomID;
    if (myRoom.isEmpty) return;

    final buildings = game.world.children
        .whereType<DoorEntity>()
        .where((d) => d.roomID == myRoom)
        .cast<BaseEntity>()
        .followedBy(
          game.world.children
              .whereType<FridgeEntity>()
              .where((f) => f.roomID == myRoom)
              .cast<BaseEntity>(),
        );

    bool anyDamaged = false;
    for (final b in buildings) {
      if (b.hp < b.maxHp) {
        anyDamaged = true;
        break;
      }
      if (b is DoorEntity && b.shieldHp < b.maxShieldHp) {
        anyDamaged = true;
        break;
      }
    }

    if (anyDamaged) {
      // AI check for cooldown
      if (repairCooldown > 0) return;

      // Defensive personalities repair instantly. Others are lazier (repair below 80% HP).
      bool shouldRepair = personality == AIPersonality.defense;
      if (!shouldRepair) {
        for (final b in buildings) {
          if (b.hp / b.maxHp < 0.8) {
            shouldRepair = true;
            break;
          }
        }
      }

      if (shouldRepair) {
        for (final b in buildings) {
          b.isBeingRepaired = true;
        }
        return;
      }
    }

    // Turn off repair if everything is healthy
    bool wasRepairing = false;
    for (final b in buildings) {
      if (b.isBeingRepaired) wasRepairing = true;
      b.isBeingRepaired = false;
    }

    if (wasRepairing) {
      repairCooldown = 20.0;
    }
  }

  @override
  void destroy() {
    if (isDestroyed) return;

    // Notify MatchManager (shows X on HUD)
    if (hunterIndex != null) {
      MatchManager.instance.killHunter(hunterIndex!);
    }

    super.destroy();
  }

  /// Puts the AI hunter to sleep.
  void sleep(Vector2 bedPosition) {
    isSleeping = true;
    scale.x = 1.0;

    // Change visuals to just the head
    _spriteComponent.sprite = _sleepingSprite;
    _spriteComponent.size = Vector2(32, 24);
    size = Vector2(32, 24);

    // Teleport to bed (aligned to pillow)
    position = bedPosition + Vector2(16, 14);
  }
}
