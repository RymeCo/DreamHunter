import 'package:flame/components.dart';
import 'package:dreamhunter/game/dreamhunter_game.dart';

class HUD extends PositionComponent with HasGameReference<DreamHunterGame> {
  HUD() : super(priority: 10);

  @override
  Future<void> onLoad() async {
    // We'll use the Viewport to add Flutter-like HUD elements
    // or just use the GameWidget's overlayBuilder.
    // For now, let's define a basic HUD component.
  }
}

/// A component that renders a Glassmorphism-style HUD element.
class HUDComponent extends Component {
  // Logic for HUD elements
}
