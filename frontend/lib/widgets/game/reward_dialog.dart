import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/widgets/glass_button.dart';
import 'package:dreamhunter/services/game/match_manager.dart';

class RewardDialog extends StatelessWidget {
  const RewardDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = MatchManager.instance;
    final bool isWin = manager.isGameWon;
    final bool isForfeited = manager.isForfeited;
    
    // Calculate values for display
    final int survivalCoins = isForfeited ? 0 : (manager.survivalTime / 15.0).floor().clamp(0, 20);
    final int damageCoins = isForfeited ? 0 : (manager.damageDealt / 50.0).floor().clamp(0, 20);
    final int killBonus = (isForfeited || !manager.playerKilledMonster) ? 0 : 10;
    final int totalCoins = isForfeited ? 0 : manager.calculateRewards();

    final minutes = (manager.survivalTime / 60).floor();
    final seconds = (manager.survivalTime % 60).floor();

    String title = isWin ? 'VICTORY' : 'DEFEAT';
    if (isForfeited) title = 'FORFEITED';

    return Center(
      child: LiquidGlassDialog(
        width: 320,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameDialogHeader(
              title: title,
              showCloseButton: false,
              isCentered: true,
            ),
            const SizedBox(height: 16),
            
            // Stats Breakdown
            _buildStatRow(
              context, 
              '⏱️ SURVIVAL', 
              '${minutes}m ${seconds}s', 
              '+$survivalCoins',
            ),
            const Divider(color: Colors.white10, height: 24),
            _buildStatRow(
              context, 
              '⚔️ DAMAGE', 
              manager.damageDealt.toInt().toString(), 
              '+$damageCoins',
            ),
            const Divider(color: Colors.white10, height: 24),
            _buildStatRow(
              context, 
              '🎯 KILL BONUS', 
              manager.playerKilledMonster ? 'YES' : 'NO', 
              '+$killBonus',
            ),
            
            const SizedBox(height: 24),
            
            // Total
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amberAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL EARNED',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amberAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '$totalCoins',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            GlassButton(
              label: 'RETURN TO DASHBOARD',
              width: double.infinity,
              height: 48,
              borderRadius: 12,
              glowColor: isForfeited ? Colors.amberAccent : (isWin ? Colors.cyanAccent : Colors.redAccent),
              onTap: () {
                // Pop the Reward Dialog
                Navigator.pop(context);
                // Pop the GameScreen to exit to Dashboard
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value, String coins) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white54,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          coins,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.amberAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
