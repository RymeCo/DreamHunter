import 'package:flame/components.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';

/// A door building that can be opened or closed.
/// When closed, it becomes solid and blocks movement.
class DoorEntity extends BaseEntity {
  final String roomID;
  bool isOpen = true;
  late final SpriteComponent _spriteComponent;
  late final Sprite _openSprite;
  late final Sprite _closedSprite;

  DoorEntity({
    required super.position,
    required this.roomID,
  }) : super(
          size: Vector2.all(32),
          anchor: Anchor.topLeft,
        ) {
    addCategory('door');
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Load both visual states
    _openSprite = await Sprite.load('game/defenses/door_wood_open-32x32.png');
    _closedSprite = await Sprite.load('game/defenses/door_wood-32x32.png');

    _spriteComponent = SpriteComponent(
      sprite: isOpen ? _openSprite : _closedSprite,
      size: size,
    );
    add(_spriteComponent);

    // If spawned closed (for future use), ensure it's solid
    if (!isOpen) {
      addCategory('building');
    }
  }

  /// Closes the door, changing its visual state and making it solid.
  void close() {
    if (!isOpen) return;
    
    isOpen = false;
    _spriteComponent.sprite = _closedSprite;
    addCategory('building');
  }

  /// Opens the door (for future use).
  void open() {
    if (isOpen) return;
    
    isOpen = true;
    _spriteComponent.sprite = _openSprite;
    categories.remove('building');
  }
}
