import 'package:flame/components.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';

/// An AI-controlled hunter entity.
/// For now, this is a visual representation of the AI hunters from the lobby.
class HunterAIEntity extends BaseEntity {
  final String skinPath;
  late final SpriteComponent _spriteComponent;

  HunterAIEntity({required this.skinPath, super.position})
      : super(
          size: Vector2(32, 48), // Standard character size
          anchor: Anchor.center,
        ) {
    addCategory('ai_hunter');
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load the sprite (Asset is already pre-cached by GameLoader)
    // Strip "assets/images/" because Flame's Sprite.load assumes images/ directory
    final imagePath = skinPath.replaceFirst('assets/images/', '');
    final sprite = await Sprite.load(imagePath);

    _spriteComponent = SpriteComponent(
      sprite: sprite,
      size: size,
    );

    add(_spriteComponent);
  }
}
