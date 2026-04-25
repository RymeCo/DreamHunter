import 'package:flutter/material.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/core/theme/app_theme.dart';

/// A compact, in-match HUD to display gameplay-specific currency (Coins & Energy Stones).
/// Refined to stack vertically and match the scale of other UI elements.
class GameEconomyHUD extends StatelessWidget {
  const GameEconomyHUD({super.key});

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<GlassTheme>() ?? const GlassTheme();

    return ListenableBuilder(
      listenable: MatchManager.instance,
      builder: (context, child) {
        final manager = MatchManager.instance;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Match Coins (Building/Upgrading)
            _buildEconomyBox(
              context,
              glass,
              icon: Icons.monetization_on_rounded,
              value: '${manager.matchCoins}',
              color: Colors.amberAccent,
            ),
            const SizedBox(height: 6),
            // Match Energy (Skill/Action stone)
            _buildEconomyBox(
              context,
              glass,
              icon: Icons.bolt_rounded,
              value: '${manager.matchEnergy}',
              color: Colors.cyanAccent,
            ),
          ],
        );
      },
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
      // Reduced padding for a more compact look
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14), // Smaller icon
          const SizedBox(width: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11, // Smaller font to match timer scale
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
