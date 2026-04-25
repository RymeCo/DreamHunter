import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/widgets/glass_button.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';

/// A reusable, standardized dialog for upgrading buildings (Bed, Generator, Door, Turrets).
class UpgradeDialog extends StatelessWidget {
  final String title;
  final int currentLevel;
  final List<String> requirements;
  final int coinCost;
  final VoidCallback onUpgrade;

  const UpgradeDialog({
    super.key,
    required this.title,
    required this.currentLevel,
    required this.requirements,
    required this.coinCost,
    required this.onUpgrade,
  });

  /// Static helper to show the dialog
  static Future<void> show(
    BuildContext context, {
    required String title,
    required int currentLevel,
    required List<String> requirements,
    required int coinCost,
    required VoidCallback onUpgrade,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: "UpgradeDialog",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation,
            child: UpgradeDialog(
              title: title,
              currentLevel: currentLevel,
              requirements: requirements,
              coinCost: coinCost,
              onUpgrade: onUpgrade,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LiquidGlassDialog(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            GameDialogHeader(title: title),
            
            // Level Indicator
            _buildInfoRow(context, "Current Level", "Lv. $currentLevel", Colors.white70),
            
            const SizedBox(height: 16),
            
            // Requirements Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "REQUIREMENTS",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white38,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (requirements.isEmpty)
              _buildRequirementRow(context, "None", true)
            else
              ...requirements.map((req) => _buildRequirementRow(context, req, true)),

            const SizedBox(height: 24),

            // Upgrade Button
            GlassButton(
              width: double.infinity,
              height: 50,
              onTap: () {
                AudioManager.instance.playClick();
                HapticManager.instance.medium();
                onUpgrade();
                Navigator.pop(context);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "UPGRADE",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Cost Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on_rounded, color: Colors.amberAccent, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          "$coinCost",
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(BuildContext context, String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle_outline_rounded : Icons.radio_button_unchecked_rounded,
            color: isMet ? Colors.greenAccent : Colors.white24,
            size: 14,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.white : Colors.white24,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
