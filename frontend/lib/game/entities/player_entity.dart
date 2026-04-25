import 'package:flame/components.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/game/behaviors/player_movement_behavior.dart';
import 'package:dreamhunter/game/ui/dynamic_joystick.dart';
import 'package:dreamhunter/services/economy/shop_manager.dart';
import 'package:dreamhunter/data/item_registry.dart';

/// The playable character entity.
class PlayerEntity extends BaseEntity {
  final DynamicJoystick joystick;

  PlayerEntity({required this.joystick}) : super(
    size: Vector2(32, 48), // Standard character size
    anchor: Anchor.center,
  ) {
    addCategory('player');
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 1. Determine which character is selected
    final characterId = ShopManager.instance.selectedCharacterId;
    final item = ItemRegistry.get(characterId);
    
    // 2. Load the sprite (Asset is already pre-cached by GameLoader)
    final imagePath = item?.image.replaceFirst('assets/images/', '') ?? 'game/characters/max_front-32x48.png';
    final sprite = await Sprite.load(imagePath);
    
    // 3. Add visual representation
    add(SpriteComponent(
      sprite: sprite,
      size: size,
    ));

    // 4. Add movement behavior
    add(PlayerMovementBehavior(joystick: joystick));
  }
}
