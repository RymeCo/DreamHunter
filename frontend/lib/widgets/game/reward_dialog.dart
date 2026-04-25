import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/widgets/glass_button.dart';

class RewardDialog extends StatelessWidget {
  const RewardDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LiquidGlassDialog(
        width: 320,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GameDialogHeader(
              title: 'GAME OVER',
              showCloseButton: false,
              isCentered: true,
            ),
            const SizedBox(height: 24),
            Text(
              'THE HUNT HAS ENDED.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
            ),
            const SizedBox(height: 32),
            GlassButton(
              label: 'RETURN TO DASHBOARD',
              width: double.infinity,
              height: 48,
              borderRadius: 12,
              glowColor: Colors.cyanAccent,
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
}
