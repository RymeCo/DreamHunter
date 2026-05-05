import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/widgets/glass_button.dart';
import 'package:dreamhunter/services/core/ad_manager.dart';
import 'package:dreamhunter/services/game/match_manager.dart';
import 'package:dreamhunter/services/progression/progression_manager.dart';

class RewardDialog extends StatelessWidget {
  const RewardDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = MatchManager.instance;
    final bool isWin = manager.isGameWon;
    final bool isForfeited = manager.isForfeited;

    final minutes = (manager.survivalTime / 60).floor();
    final seconds = (manager.survivalTime % 60).floor();

    String title = isWin ? 'VICTORY' : 'DEFEAT';
    if (isForfeited) title = 'FORFEITED';

    return ListenableBuilder(
      listenable: manager,
      builder: (context, child) {
        // Recalculate values when manager notifies (e.g. rewards doubled)
        final int totalCoins = isForfeited ? 0 : manager.calculateRewards();
        final int totalXp = manager.calculateXP();

        // Stats Breakdown (These are base values for display)
        final int survivalCoins = isForfeited
            ? 0
            : (manager.survivalTime / 15.0).floor().clamp(0, 20);
        final int damageCoins = isForfeited
            ? 0
            : (manager.damageDealt / 50.0).floor().clamp(0, 20);
        final int killBonus = (isForfeited || !manager.playerKilledMonster)
            ? 0
            : 10;

        return StandardGlassPage(
          title: title,
          isCentered: true,
          showCloseButton: false,
          footer: [
            GlassButton(
              label: 'RETURN TO DASHBOARD',
              width: double.infinity,
              height: 48,
              borderRadius: 12,
              glowColor: isForfeited
                  ? Colors.amberAccent
                  : (isWin ? Colors.cyanAccent : Colors.redAccent),
              onTap: () {
                // Pop the Reward Dialog
                Navigator.pop(context);
                // Pop the GameScreen to exit to Dashboard
                Navigator.pop(context);
              },
            ),
          ],
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),

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

                // XP and Level Up Section
                ListenableBuilder(
                  listenable: ProgressionManager.instance,
                  builder: (context, child) {
                    final prog = ProgressionManager.instance;
                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'LEVEL ${prog.level}',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Colors.cyanAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              '+$totalXp XP',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: Colors.cyanAccent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: prog.progress,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.cyanAccent,
                            ),
                            minHeight: 8,
                          ),
                        ),
                        if (prog.didLevelUpThisMatch)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'LEVEL UP!',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.cyanAccent,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                            ),
                          ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Ad Button
                if (!isForfeited && !manager.isRewardsDoubled)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: GlassButton(
                      width: double.infinity,
                      height: 56,
                      glowColor: Colors.amberAccent,
                      onTap: () {
                        AdManager.instance.showRewardAd(
                          context: context,
                          onRewardEarned: () => manager.doubleRewards(),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'WATCH AD TO DOUBLE REWARDS',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Total Coins
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amberAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        manager.isRewardsDoubled
                            ? 'DOUBLED REWARD'
                            : 'TOTAL EARNED',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            color: Colors.amberAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$totalCoins',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.amberAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value,
    String coins,
  ) {
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
