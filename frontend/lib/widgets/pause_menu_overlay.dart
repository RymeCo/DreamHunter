import 'package:flutter/material.dart';
import '../game/haunted_dorm_game.dart';
import '../screens/dashboard_screen.dart';
import 'clickable_image.dart';
import 'liquid_glass_dialog.dart';
import '../services/audio_service.dart';

class PauseMenuOverlay extends StatefulWidget {
  final HauntedDormGame game;

  const PauseMenuOverlay({super.key, required this.game});

  @override
  State<PauseMenuOverlay> createState() => _PauseMenuOverlayState();
}

class _PauseMenuOverlayState extends State<PauseMenuOverlay> {
  @override
  Widget build(BuildContext context) {
    final audioService = AudioService();

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
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 10,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _buildMenuButton(
              label: 'RESUME',
              onTap: () {
                widget.game.overlays.remove('PauseMenu');
                widget.game.resumeEngine();
              },
            ),
            const SizedBox(height: 16),
            _buildMenuButton(
              label: audioService.isMusicMuted ? 'UNMUTE MUSIC' : 'MUTE MUSIC',
              glowColor: Colors.orangeAccent,
              onTap: () async {
                await audioService.toggleMusicMute();
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            _buildMenuButton(
              label: audioService.isSoundMuted ? 'UNMUTE SOUND' : 'MUTE SOUND',
              glowColor: Colors.cyanAccent,
              onTap: () async {
                await audioService.toggleSoundMute();
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            _buildMenuButton(
              label: 'QUIT GAME',
              glowColor: Colors.redAccent,
              onTap: () {
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

  Widget _buildMenuButton({
    required String label,
    required VoidCallback onTap,
    Color glowColor = Colors.deepPurpleAccent,
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
