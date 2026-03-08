import 'package:flame/components.dart';

class CollisionBlock extends PositionComponent {
  bool isPassable;

  CollisionBlock({
    required super.position,
    required super.size,
    this.isPassable = false,
  });
}
