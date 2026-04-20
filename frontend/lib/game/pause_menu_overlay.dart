import 'package:flutter/material.dart';
import 'package:dreamhunter/game/dreamhunter_game.dart';
import 'package:dreamhunter/screens/dashboard_screen.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/glass_button.dart';

/// A Flutter-based overlay for the Pause Menu.
/// Managed by Flame's OverlayManager.
class PauseMenuOverlay extends StatelessWidget {
  final DreamHunterGame game;

  const PauseMenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LiquidGlassDialog(
        width: 280,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PAUSED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 40),

            // RESUME BUTTON
            GlassButton(
              label: 'RESUME',
              width: double.infinity,
              height: 50,
              glowColor: Colors.deepPurpleAccent,
              onTap: () {
                game.overlays.remove('PauseMenu');
                game.resumeEngine();
              },
            ),
            const SizedBox(height: 16),

            // EXIT BUTTON
            GlassButton(
              label: 'QUIT GAME',
              width: double.infinity,
              height: 50,
              glowColor: Colors.redAccent,
              onTap: () {
                // 1. Properly dispose the game instance and data
                game.disposeGame();

                // 2. Kill the gameplay by navigating back
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const DashboardScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
