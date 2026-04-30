import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
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
         size: Vector2.all(16), // Projectiles are usually smaller than 32x32
         anchor: Anchor.center,
       ) {
    // 20% scale boost as requested
    scale = Vector2.all(1.2);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
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
