import 'package:flutter/material.dart';
import 'liquid_glass_dialog.dart';
import 'clickable_image.dart';
import 'custom_snackbar.dart';

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
    return LiquidGlassDialog(
      title: 'INSUFFICIENT FUNDS',
      maxWidth: 340,
      children: [
        const Icon(
          Icons.account_balance_wallet_rounded,
          color: Colors.amberAccent,
          size: 60,
        ),
        const SizedBox(height: 20),
        Text(
          'You need $neededAmount Dream Coins, but you only have $currentAmount.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 16,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Would you like to exchange some Hell Stones for Dream Coins?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.amberAccent,
            fontSize: 14,
            fontWeight: FontWeight.w600,
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
          child: const Text(
            'GO TO EXCHANGE',
            style: TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassButton(
          onTap: () => Navigator.pop(context),
          glowColor: Colors.white24,
          width: double.infinity,
          height: 45,
          color: Colors.transparent,
          child: Text(
            'MAYBE LATER',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
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
