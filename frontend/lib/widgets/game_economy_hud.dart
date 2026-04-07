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
    return StreamBuilder(
      stream: Stream.periodic(const Duration(milliseconds: 500)),
      builder: (context, snapshot) {
        return Positioned(
          top: 40,
          left: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEconomyChip(
                emoji: '💰',
                label: 'COINS',
                value: widget.game.player.energy.toInt(),
                color: Colors.amberAccent,
              ),
              const SizedBox(height: 8),
              _buildEconomyChip(
                emoji: '⚡',
                label: 'ENERGY',
                value: widget.game.player.energy.toInt(),
                color: Colors.blueAccent,
              ),
            ],
          ),
        );
      }
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
