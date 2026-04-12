import 'package:flutter/material.dart';
import '../game/haunted_dorm_game.dart';
import 'liquid_glass_dialog.dart';

class GameEconomyHUD extends StatefulWidget {
  final HauntedDormGame game;
  const GameEconomyHUD({super.key, required this.game});

  @override
  State<GameEconomyHUD> createState() => _GameEconomyHUDState();
}

class _GameEconomyHUDState extends State<GameEconomyHUD> {
  @override
  Widget build(BuildContext context) {
    // FIX: Positioned must be at the ROOT of the overlay
    return Positioned(
      top: 110,
      left: 20,
      child: StreamBuilder(
        stream: Stream.periodic(const Duration(milliseconds: 500)),
        builder: (context, snapshot) {
          // SAFETY: Check if player is initialized before reading values
          // Using a try-catch because 'player' is a late variable
          try {
            final energy = widget.game.player.energy.toInt();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEconomyChip(
                  emoji: '💰',
                  label: 'COINS',
                  value: energy,
                  color: Colors.amberAccent,
                ),
                const SizedBox(height: 8),
                _buildEconomyChip(
                  emoji: '⚡',
                  label: 'ENERGY',
                  value: energy,
                  color: Colors.blueAccent,
                ),
              ],
            );
          } catch (e) {
            // Player not ready yet, show empty chips
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget _buildEconomyChip({
    required String emoji,
    required String label,
    required int value,
    required Color color,
  }) {
    return LiquidGlassDialog(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      borderRadius: 12,
      blurSigma: 6,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
