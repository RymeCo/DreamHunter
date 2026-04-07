import 'package:flutter/material.dart';
import '../game/haunted_dorm_game.dart';
import '../game/core/game_config.dart';
import 'liquid_glass_dialog.dart';

class UpgradeMenu extends StatelessWidget {
  final HauntedDormGame game;
  const UpgradeMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final turret = game.activeTurret;
    if (turret == null) return const SizedBox.shrink();

    final int nextLevel = turret.level + 1;
    final bool canUpgrade = nextLevel <= 9;
    final int cost = canUpgrade ? GameConfig.turretUpgradeCosts[nextLevel - 2] : 0;
    final bool canAfford = game.player.energy >= cost;

    return Center(
      child: LiquidGlassDialog(
        width: 250,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TURRET LV${turret.level}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            if (canUpgrade) ...[
              Text(
                'Next Level: Lv$nextLevel',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: canAfford ? () {
                  game.player.energy -= cost;
                  turret.upgrade();
                  game.overlays.remove('UpgradeMenu');
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAfford ? Colors.deepPurpleAccent : Colors.grey,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text('UPGRADE (⚡ $cost)'),
              ),
            ] else 
              const Text('MAX LEVEL REACHED', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
            
            TextButton(
              onPressed: () => game.overlays.remove('UpgradeMenu'),
              child: const Text('CLOSE', style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }
}
