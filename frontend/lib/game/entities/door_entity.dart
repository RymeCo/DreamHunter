import 'package:flame/components.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';

/// A door building that can be opened or closed.
/// For now, it is in an 'Open' state and walkable.
class DoorEntity extends BaseEntity {
  bool isOpen = true;

  DoorEntity({
    required super.position,
  }) : super(
          size: Vector2.all(32),
          anchor: Anchor.topLeft,
        ) {
    addCategory('door');
    // We don't add 'building' category yet to keep it walkable in the global check
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Load visual sprite (Open state by default)
    final sprite = await Sprite.load('game/defenses/door_wood_open-32x32.png');
    add(SpriteComponent(
      sprite: sprite,
      size: size,
    ));
  }
}
