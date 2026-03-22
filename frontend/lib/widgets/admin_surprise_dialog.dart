import 'dart:ui';
import 'package:flutter/material.dart';

class AdminSurpriseDialog extends StatelessWidget {
  final Map<String, dynamic> tweakData;

  const AdminSurpriseDialog({super.key, required this.tweakData});

  @override
  Widget build(BuildContext context) {
    final String reason = tweakData['reason'] ?? 'Administrator Adjustment';
    
    // Extract changes for display
    final int dc = tweakData['dreamCoins'] ?? 0;
    final int hs = tweakData['hellStones'] ?? 0;
    final int xp = tweakData['xp'] ?? 0;
    final int level = tweakData['level'] ?? 0;

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'ADMIN SURPRISE!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const Divider(height: 32, color: Colors.white10),
                  
                  _buildTweakItem('Dream Coins', dc, Icons.cloud_circle, Colors.cyanAccent),
                  _buildTweakItem('Hell Stones', hs, Icons.local_fire_department, Colors.orangeAccent),
                  _buildTweakItem('Level', level, Icons.trending_up, Colors.greenAccent),
                  _buildTweakItem('XP', xp, Icons.bolt, Colors.blueAccent),
                  
                  const SizedBox(height: 24),
                  const Text(
                    'Your local save has been synchronized with the master service.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  const SizedBox(height: 16),
                  
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text('AWESOME!', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTweakItem(String label, int value, IconData icon, Color color) {
    if (value == 0) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          Text(
            value > 0 ? '+$value' : '$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
