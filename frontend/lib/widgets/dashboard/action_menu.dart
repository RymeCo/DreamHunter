import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/glass_button.dart';

class DashboardActionMenu extends StatelessWidget {
  final VoidCallback onDailyTasksTap;
  final VoidCallback onLeaderboardTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onExitTap;

  const DashboardActionMenu({
    super.key,
    required this.onDailyTasksTap,
    required this.onLeaderboardTap,
    required this.onSettingsTap,
    required this.onExitTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassDialog(
      width: 220,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMenuButton(
            icon: Icons.assignment_rounded,
            label: 'Daily Tasks',
            onTap: onDailyTasksTap,
          ),
          _buildMenuButton(
            icon: Icons.leaderboard_rounded,
            label: 'Leaderboard',
            onTap: onLeaderboardTap,
          ),
          _buildMenuButton(
            icon: Icons.settings_rounded,
            label: 'Settings',
            onTap: onSettingsTap,
          ),
          _buildMenuButton(
            icon: Icons.power_settings_new_rounded,
            label: 'Exit Game',
            onTap: onExitTap,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: GlassButton(
        onTap: onTap,
        width: double.infinity,
        height: 50,
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withValues(alpha: 0.05),
        hoverColor: Colors.deepPurpleAccent.withValues(alpha: 0.1),
        borderColor: Colors.white.withValues(alpha: 0.1),
        hoverBorderColor: Colors.deepPurpleAccent,
        glowColor: Colors.deepPurpleAccent,
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
