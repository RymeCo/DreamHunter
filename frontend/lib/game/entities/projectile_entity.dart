import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';

class ProjectileEntity extends SpriteComponent
    with HasGameReference<DreamHunterGame>, CollisionCallbacks {
  final Vector2 velocity;
  final double damage;

  ProjectileEntity({
    required super.sprite,
    required super.position,
    required this.velocity,
    this.damage = 10,
  }) : super(
         size: Vector2(16, 4), // Stretched for a tracer look
         anchor: Anchor.center,
       ) {
    // 20% scale boost as requested
    scale = Vector2.all(1.2);
    // Rotate to match velocity
    angle = velocity.angleToSigned(Vector2(1, 0)) * -1;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());

    // Add a trailing "tracer" glow
    add(
      RectangleComponent(
        size: Vector2(size.x * 2, size.y),
        position: Vector2(-size.x, 0),
        paint: Paint()..color = Colors.yellowAccent.withValues(alpha: 0.3),
        anchor: Anchor.centerLeft,
      ),
    );
  }

  double _lifespan = 2.0;

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt;

    _lifespan -= dt;
    if (_lifespan <= 0) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is BaseEntity && other.hasCategory('monster')) {
      other.takeDamage(damage);
      removeFromParent();
    }
  }
}
