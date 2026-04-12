import 'package:flutter/material.dart';
import '../game/haunted_dorm_game.dart';
import 'liquid_glass_dialog.dart';

/// A professional, compact HUD that displays player's coins and energy.
/// Uses the reusable LiquidGlassDialog for consistent theme.
class GameEconomyHUD extends StatelessWidget {
  final HauntedDormGame game;

  const GameEconomyHUD({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 50,
      left: 20,
      child: StreamBuilder(
        stream: Stream.periodic(const Duration(milliseconds: 250)),
        builder: (context, snapshot) {
          try {
            final energy = game.player.energy.toInt();
            final coins = game.player.coins.toInt();

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatItem(
                  icon: Icons.monetization_on_rounded,
                  label: 'COINS',
                  value: coins,
                  color: Colors.amberAccent,
                ),
                const SizedBox(height: 8),
                _buildStatItem(
                  icon: Icons.bolt_rounded,
                  label: 'ENERGY',
                  value: energy,
                  color: Colors.blueAccent,
                ),
              ],
            );
          } catch (e) {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return LiquidGlassDialog(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      borderRadius: 10,
      blurSigma: 4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
