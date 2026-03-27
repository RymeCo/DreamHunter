import 'package:flutter/material.dart';
import '../liquid_glass_dialog.dart';

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
          const Divider(color: Colors.white10),
          _buildMenuButton(
            icon: Icons.leaderboard_rounded,
            label: 'Leaderboard',
            onTap: onLeaderboardTap,
          ),
          const Divider(color: Colors.white10),
          _buildMenuButton(
            icon: Icons.settings_rounded,
            label: 'Settings',
            onTap: onSettingsTap,
          ),
          const Divider(color: Colors.white10),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
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
      ),
    );
  }
}
