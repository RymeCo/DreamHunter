import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

/// The foundational class for all game objects (players, monsters, furniture, etc.)
/// Adheres to the Composition & Behavior Architecture mandate.
abstract class BaseEntity extends PositionComponent with CollisionCallbacks {
  /// Tags for categorizing entities (e.g., 'player', 'monster', 'obstacle')
  final Set<String> categories = {};

  BaseEntity({
    super.position,
    super.size,
    super.anchor,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Add a hitbox at the feet (bottom of the sprite)
    // For a 32x48 sprite, we'll make it 24x12 centered at the bottom
    add(RectangleHitbox(
      size: Vector2(size.x * 0.75, size.y * 0.25),
      position: Vector2(size.x * 0.125, size.y * 0.75),
    ));
  }

  /// Helper to check if this entity has a specific category.
  bool hasCategory(String category) => categories.contains(category);

  /// Helper to add a category.
  void addCategory(String category) => categories.add(category);
}
