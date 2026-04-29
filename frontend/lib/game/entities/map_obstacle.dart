import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

/// A static collision object parsed from the Tiled map.
class MapObstacle extends PositionComponent {
  MapObstacle({required super.position, required super.size})
    : super(anchor: Anchor.topLeft);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox()..collisionType = CollisionType.passive);
  }
}
