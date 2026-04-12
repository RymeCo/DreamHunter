import 'dart:async';
import 'building_component.dart';

class Generator extends BuildingComponent {
  double _timer = 0;

  Generator({required super.position, required super.size, super.level = 1})
    : super(maxHealth: 150);

  @override
  String get interactionAction => 'UPGRADE (Lv$level)';

  @override
  void onInteract() {
    // Show upgrade menu for generators
    game.activeSlot = null; // We are interacting with an existing object
    game.overlays.add(
      'BuildMenu',
    ); // Reuse build menu for upgrade logic or separate?
  }

  @override
  FutureOr<void> onLoad() async {
    final name = 'generator_lv$level-32x32.png';
    sprite = await game.loadSprite('game/economy/$name');
    return super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Generate extra energy/coins every 1 second
    _timer += dt;
    if (_timer >= 1.0) {
      _timer = 0;
      game.player.energy += (level * 2);
    }
  }
}
