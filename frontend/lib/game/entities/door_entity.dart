import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dreamhunter/game/entities/base_entity.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/widgets/game/upgrade_dialog.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/game/game_config.dart';

/// A door building that can be opened or closed.
/// Every 5 upgrades increases the Tier (Wood -> Iron -> Gold).
/// The Level within a Tier is represented by Suffixes (I, II, III, IV, V).
class DoorEntity extends BaseEntity with TapCallbacks {
  final String roomID;
  bool isOpen = true;
  bool isDestroyed = false;

  // Level and Health Properties
  int totalUpgrades = 0; // Current Level (0 to 14)

  DoorUpgrade get currentUpgrade => GameConfig.doorUpgrades[totalUpgrades];

  String get romanNumeral => currentUpgrade.suffix;

  String get levelName => currentUpgrade.name;

  double maxHp = 35; // Default Wood I HP
  late double currentHp;

  late final SpriteComponent _spriteComponent;
  late Sprite _openSprite;
  late Sprite _closedSprite;

  late final TextComponent _levelText;

  // Health Bar Components
  late final _RoundedBarComponent _hbBackground;
  late final _RoundedBarComponent _hbFill;

  DoorEntity({required super.position, required this.roomID})
    : super(size: Vector2.all(32), anchor: Anchor.topLeft) {
    addCategory('door');
    maxHp = currentUpgrade.hp;
    currentHp = maxHp;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 1. Load initial sprites based on material
    await _updateSprites();

    _spriteComponent = SpriteComponent(
      sprite: isOpen ? _openSprite : _closedSprite,
      size: size,
    );
    add(_spriteComponent);

    // 2. Initialize Health Bar
    _hbBackground = _RoundedBarComponent(
      position: Vector2(4, 16),
      size: Vector2(24, 5),
      radius: 2.5,
      paint: Paint()..color = Colors.black.withValues(alpha: 0.7),
    );

    _hbFill = _RoundedBarComponent(
      position: Vector2(0, 0),
      size: Vector2(24, 5),
      radius: 2.5,
      paint: Paint()..color = Colors.greenAccent,
    );

    _hbBackground.add(_hbFill);
    add(_hbBackground);

    // 3. Initialize Level Text Indicator
    _levelText = TextComponent(
      text: romanNumeral,
      textRenderer: TextPaint(
        style: GoogleFonts.quicksand(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          shadows: [
            const Shadow(
              blurRadius: 2.0,
              color: Colors.black,
              offset: Offset(1.0, 1.0),
            ),
          ],
        ),
      ),
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2 - 4),
    );
    add(_levelText);

    _updateLevelText();
    _updateHealthBar();

    if (!isOpen) {
      addCategory('building');
    }
  }

  void _updateLevelText() {
    if (isDestroyed) return;
    _levelText.text = isOpen ? '' : romanNumeral;
  }

  Future<void> _updateSprites() async {
    final material = currentUpgrade.material.toLowerCase();
    String assetName = material;
    if (material == 'iron') assetName = 'steel'; // Map 'iron' to 'steel' assets

    _openSprite = await Sprite.load(
      'game/defenses/door_${assetName}_open-32x32.png',
    );
    _closedSprite = await Sprite.load(
      'game/defenses/door_$assetName-32x32.png',
    );

    if (isLoaded) {
      _spriteComponent.sprite = isOpen ? _openSprite : _closedSprite;
    }
  }

  void takeDamage(double amount) {
    if (isDestroyed) return;
    currentHp = (currentHp - amount).clamp(0, maxHp);
    _updateHealthBar();
    if (currentHp <= 0) destroy();
  }

  void _updateHealthBar() {
    if (isDestroyed) return;
    final bool isDamaged = currentHp < maxHp;

    if (isDamaged && !isOpen) {
      _hbBackground.renderBar = true;
      _hbFill.renderBar = true;
      _hbFill.size.x = (currentHp / maxHp) * 24.0;
      final hpPercent = currentHp / maxHp;
      if (hpPercent < 0.25) {
        _hbFill.paint.color = Colors.redAccent;
      } else if (hpPercent < 0.5) {
        _hbFill.paint.color = Colors.orangeAccent;
      } else {
        _hbFill.paint.color = Colors.greenAccent;
      }
    } else {
      _hbBackground.renderBar = false;
      _hbFill.renderBar = false;
    }
  }

  void destroy() {
    if (isDestroyed) return;
    isDestroyed = true;
    _spriteComponent.removeFromParent();
    _hbBackground.removeFromParent();
    categories.remove('building');
    HapticManager.instance.heavy();
  }

  void close() {
    if (!isOpen || isDestroyed) return;
    isOpen = false;
    _spriteComponent.sprite = _closedSprite;
    addCategory('building');
    _updateLevelText();
    _updateHealthBar();
  }

  void open() {
    if (isOpen || isDestroyed) return;
    isOpen = true;
    _spriteComponent.sprite = _openSprite;
    categories.remove('building');
    _updateLevelText();
    _updateHealthBar();
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (isDestroyed) return;
    final manager = MatchManager.instance;
    if (manager.currentRoomID != roomID) return;

    if (totalUpgrades >= GameConfig.doorUpgrades.length - 1) {
      UpgradeDialog.show(
        game.buildContext!,
        title: "Door",
        currentLevel: totalUpgrades + 1,
        levelDisplay: _buildLevelWidget(),
        requirements: [],
        coinCost: 0,
        upgradeBenefit: "MAXED OUT",
        isMaxLevel: true,
        onUpgrade: () {},
      );
      return;
    }

    final nextUpgrade = GameConfig.doorUpgrades[totalUpgrades + 1];

    UpgradeDialog.show(
      game.buildContext!,
      title: "Door",
      currentLevel: totalUpgrades + 1,
      levelDisplay: _buildLevelWidget(),
      requirements: [],
      coinCost: nextUpgrade.cost.coins,
      energyCost: nextUpgrade.cost.energy,
      upgradeBenefit:
          "Lv. ${totalUpgrades + 1} ➔ Lv. ${totalUpgrades + 2}\n${maxHp.toInt()} ➔ ${nextUpgrade.hp.toInt()} HP",
      onUpgrade: () async {
        final success = MatchManager.instance.spendResources(
          coins: nextUpgrade.cost.coins,
          energy: nextUpgrade.cost.energy,
        );
        if (success) {
          totalUpgrades++;
          maxHp = currentUpgrade.hp;
          currentHp = maxHp;
          await _updateSprites();
          _updateLevelText();
          _updateHealthBar();
        }
      },
    );
  }

  Widget _buildLevelWidget() {
    return Text(
      currentUpgrade.name.toUpperCase(),
      textAlign: TextAlign.right,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _RoundedBarComponent extends RectangleComponent {
  final double radius;
  bool renderBar = true;
  _RoundedBarComponent({
    required this.radius,
    super.position,
    super.size,
    super.paint,
  });
  @override
  void render(Canvas canvas) {
    if (!renderBar) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), Radius.circular(radius)),
      paint,
    );
  }

  @override
  void renderTree(Canvas canvas) {
    if (!renderBar) return;
    super.renderTree(canvas);
  }
}
