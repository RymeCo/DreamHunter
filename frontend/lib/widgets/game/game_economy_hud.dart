import 'package:flutter/material.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/core/theme/app_theme.dart';
import 'package:dreamhunter/game/dream_hunter_game.dart';
import 'package:dreamhunter/widgets/game/character_portrait.dart';
import 'package:dreamhunter/services/economy/shop_manager.dart';
import 'package:dreamhunter/data/item_registry.dart';

/// A compact, in-match HUD to display gameplay-specific currency and Hunter list for camera snapping.
class GameEconomyHUD extends StatelessWidget {
  final DreamHunterGame game;

  const GameEconomyHUD({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final glass =
        Theme.of(context).extension<GlassTheme>() ?? const GlassTheme();

    return ListenableBuilder(
      listenable: MatchManager.instance,
      builder: (context, child) {
        final manager = MatchManager.instance;
        final isMasked = !manager.isHunterSleeping;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Match Coins (Building/Upgrading)
            _buildEconomyBox(
              context,
              glass,
              icon: Icons.monetization_on_rounded,
              value: isMasked
                  ? '0'
                  : (manager.matchCoins > 100000
                        ? '100000+'
                        : '${manager.matchCoins}'),
              color: Colors.amberAccent,
            ),
            const SizedBox(height: 6),
            // Match Energy (Skill/Action stone)
            _buildEconomyBox(
              context,
              glass,
              icon: Icons.bolt_rounded,
              value: isMasked
                  ? '0'
                  : (manager.matchEnergy > 999
                        ? '999+'
                        : '${manager.matchEnergy}'),
              color: Colors.cyanAccent,
            ),
            const SizedBox(height: 12),
            // Hunter List (Camera Hot-Swap)
            _buildHunterList(context),
          ],
        );
      },
    );
  }

  Widget _buildHunterList(BuildContext context) {
    final characterId = ShopManager.instance.selectedCharacterId;
    final item = ItemRegistry.get(characterId);
    final playerImagePath =
        item?.image ?? 'assets/images/game/characters/max_front-32x48.png';
    final aiSkins = MatchManager.instance.aiSkins;

    return SizedBox(
      width: 110, // Width to fit 3 icons (32px + 6px spacing)
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: List.generate(1 + aiSkins.length, (index) {
          final isPlayer = index == 0;
          final imagePath = isPlayer ? playerImagePath : aiSkins[index - 1];
          final isSleeping = MatchManager.instance.isHunterSleeping;

          return _buildHunterIcon(
            context,
            imagePath: imagePath,
            onTap: () {
              // Only allow camera snapping if player is sleeping
              if (isSleeping) {
                game.centerCameraOnHunter(index);
              }
            },
            isLocalPlayer: isPlayer,
            isGray: false, // Always colorful as requested
          );
        }),
      ),
    );
  }

  Widget _buildHunterIcon(
    BuildContext context, {
    required String imagePath,
    required VoidCallback onTap,
    bool isLocalPlayer = false,
    bool isGray = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isLocalPlayer
                ? Colors.greenAccent.withValues(alpha: 0.5)
                : Colors.white12,
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CharacterPortrait(
                imagePath: imagePath,
                size: 28,
                isGray: isGray,
              ),
            ),
            if (isLocalPlayer)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  color: Colors.greenAccent.withValues(alpha: 0.7),
                  padding: const EdgeInsets.symmetric(vertical: 0.5),
                  child: const Text(
                    'YOU',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 6,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEconomyBox(
    BuildContext context,
    GlassTheme glass, {
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 90, // Standardized fixed width
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.0),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14), // Smaller icon
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11, // Smaller font to match timer scale
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
