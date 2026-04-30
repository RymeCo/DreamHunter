import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/behaviors/monster_ai_behavior.dart';

class MonsterEntity extends BaseEntity {
  double speed = 80.0;
  double attackDamage = 5.0;
  int monsterLevel = 1;
  int experience = 0;

  late final SpriteComponent _spriteComponent;
  late final _MonsterHealthBar _healthBar;

  MonsterEntity({super.position})
    : super(size: Vector2(32, 48), anchor: Anchor.bottomCenter) {
    addCategory('monster');
    maxHp = 100.0;
    hp = maxHp;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load sprite
    final sprite = await Sprite.load('game/monsters/ghost_idle-32x48.png');
    _spriteComponent = SpriteComponent(sprite: sprite, size: size);
    add(_spriteComponent);

    // Add health bar
    _healthBar = _MonsterHealthBar();
    add(_healthBar);

    // Add AI behavior
    add(MonsterAIBehavior());
  }

  void gainExperience(int amount) {
    experience += amount;
    if (experience >= 20) {
      experience -= 20;
      _levelUp();
    }
  }

  void _levelUp() {
    monsterLevel++;
    maxHp *= 1.2;
    hp = maxHp; // Full heal on level up
    attackDamage *= 1.1;
    
    // Visual feedback for level up could be added here
  }

  @override
  void takeDamage(double amount) {
    super.takeDamage(amount);
    _healthBar.updateVisuals();
  }
}

class _MonsterHealthBar extends RectangleComponent with ParentIsA<MonsterEntity> {
  late final RectangleComponent _fill;

  _MonsterHealthBar()
    : super(
        position: Vector2(4, -8),
        size: Vector2(24, 4),
        paint: Paint()..color = Colors.black.withValues(alpha: 0.7),
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _fill = RectangleComponent(
      size: Vector2(24, 4),
      paint: Paint()..color = Colors.redAccent,
    );
    add(_fill);
  }

  void updateVisuals() {
    _fill.size.x = (parent.hp / parent.maxHp) * 24.0;
  }
}
