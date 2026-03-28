import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dreamhunter/game/dreamhunter_game.dart';
import 'package:dreamhunter/screens/dashboard_screen.dart';
import 'package:dreamhunter/widgets/clickable_image.dart';

class PauseMenuOverlay extends StatefulWidget {
  final DreamHunterGame game;

  const PauseMenuOverlay({super.key, required this.game});

  @override
  State<PauseMenuOverlay> createState() => _PauseMenuOverlayState();
}

class _PauseMenuOverlayState extends State<PauseMenuOverlay> {
  bool _isMuted = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 250,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PAUSED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 32),
                _buildMenuButton(
                  label: 'RESUME',
                  onTap: () {
                    widget.game.overlays.remove('PauseMenu');
                    widget.game.resumeEngine();
                  },
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  label: _isMuted ? 'UNMUTE' : 'MUTE',
                  glowColor: Colors.orangeAccent,
                  onTap: () {
                    setState(() => _isMuted = !_isMuted);
                    // Placeholder for actual mute logic
                  },
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  label: 'QUIT GAME',
                  glowColor: Colors.redAccent,
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const DashboardScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required String label,
    required VoidCallback onTap,
    Color glowColor = Colors.blueAccent,
  }) {
    return GlassButton(
      label: label,
      onTap: onTap,
      width: double.infinity,
      height: 50,
      borderRadius: 16,
      glowColor: glowColor,
      pulseMinOpacity: 0.5,
    );
  }
}
