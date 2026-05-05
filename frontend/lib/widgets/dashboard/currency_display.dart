import 'package:flutter/material.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/network_monitor.dart';
import 'package:dreamhunter/services/economy/wallet_manager.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';

class CurrencyDisplay extends StatelessWidget {
  final WalletManager controller;
  final VoidCallback onProfileTap;
  final VoidCallback onExchangeTap;
  final VoidCallback onPurchaseTap;

  const CurrencyDisplay({
    super.key,
    required this.controller,
    required this.onProfileTap,
    required this.onExchangeTap,
    required this.onPurchaseTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final int coins = controller.dreamCoins;
        final int stones = controller.hellStones;

        return Row(
          children: [
            GestureDetector(
              onTap: () {
                AudioManager().playClick();
                onProfileTap();
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.blueAccent.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.black45,
                      backgroundImage: AssetImage(
                        'assets/images/dashboard/profile.png',
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: NetworkMonitor().isOnline,
                        builder: (context, isOnline, child) {
                          return Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrencyChip(
                    context,
                    icon: Icons.toll_rounded,
                    value: '$coins',
                    color: Colors.amberAccent,
                    onPlusTap: onExchangeTap,
                  ),
                  const SizedBox(height: 4),
                  _buildCurrencyChip(
                    context,
                    icon: Icons.diamond_rounded,
                    value: '$stones',
                    color: Colors.redAccent,
                    onPlusTap: onPurchaseTap,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCurrencyChip(
    BuildContext context, {
    required IconData icon,
    required String value,
    required Color color,
    VoidCallback? onPlusTap,
  }) {
    return LiquidGlassDialog(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      borderRadius: 12,
      blurSigma: 4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontSize: 13),
          ),
          if (onPlusTap != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                AudioManager().playClick();
                onPlusTap();
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, color: color, size: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
