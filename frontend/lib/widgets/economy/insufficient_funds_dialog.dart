import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/glass_button.dart';

/// A reusable "Liquid Glass" dialog to notify users when they are short on Dream Coins.
class InsufficientFundsDialog extends StatelessWidget {
  final int neededAmount;
  final int currentAmount;
  final VoidCallback? onGoToExchange;

  const InsufficientFundsDialog({
    super.key,
    required this.neededAmount,
    required this.currentAmount,
    this.onGoToExchange,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: LiquidGlassDialog(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'INSUFFICIENT FUNDS',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 18, letterSpacing: 2),
            ),
            const SizedBox(height: 20),
            const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.amberAccent,
              size: 60,
            ),
            const SizedBox(height: 20),
            Text(
              'You need $neededAmount Dream Coins, but you only have $currentAmount.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Would you like to exchange some Hell Stones for Dream Coins?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.amberAccent,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 30),
            GlassButton(
              onTap: () {
                Navigator.pop(context); // Close dialog
                if (onGoToExchange != null) {
                  onGoToExchange!();
                }
              },
              glowColor: Colors.amberAccent,
              width: double.infinity,
              height: 50,
              label: 'GO TO EXCHANGE',
              hoverTextColor: Colors.amberAccent,
            ),
            const SizedBox(height: 12),
            GlassButton(
              onTap: () => Navigator.pop(context),
              glowColor: Colors.white24,
              width: double.infinity,
              height: 45,
              color: Colors.transparent,
              label: 'MAYBE LATER',
              hoverTextColor: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

  /// Static helper to show the dialog easily
  static void show(
    BuildContext context, {
    required int needed,
    required int current,
    VoidCallback? onGoToExchange,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => InsufficientFundsDialog(
        neededAmount: needed,
        currentAmount: current,
        onGoToExchange: onGoToExchange,
      ),
    );
  }
}
