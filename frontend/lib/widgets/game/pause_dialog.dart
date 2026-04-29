import 'package:flutter/material.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/widgets/glass_button.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';

class PauseDialog extends StatefulWidget {
  const PauseDialog({super.key});

  @override
  State<PauseDialog> createState() => _PauseDialogState();
}

class _PauseDialogState extends State<PauseDialog> {
  final AudioManager _audioManager = AudioManager.instance;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LiquidGlassDialog(
        width: 320,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GameDialogHeader(
              title: 'PAUSED',
              showCloseButton: true,
              isCentered: true,
            ),
            const SizedBox(height: 16),

            // Audio Controls Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAudioToggle(
                  icon: _audioManager.isMusicMuted
                      ? Icons.music_off_rounded
                      : Icons.music_note_rounded,
                  label: 'MUSIC',
                  isMuted: _audioManager.isMusicMuted,
                  onTap: () async {
                    await _audioManager.toggleMusicMute();
                    setState(() {});
                  },
                ),
                _buildAudioToggle(
                  icon: _audioManager.isSoundMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  label: 'SOUND',
                  isMuted: _audioManager.isSoundMuted,
                  onTap: () async {
                    await _audioManager.toggleSoundMute();
                    setState(() {});
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Quit Button
            GlassButton(
              label: 'QUIT GAME',
              width: double.infinity,
              height: 45,
              borderRadius: 12,
              glowColor: Colors.redAccent,
              hoverColor: Colors.redAccent.withValues(alpha: 0.15),
              hoverBorderColor: Colors.redAccent,
              hoverTextColor: Colors.redAccent,
              onTap: () {
                // Return 'quit' to the caller (GameScreen) to trigger the Reward Screen
                Navigator.pop(context, 'quit');
              },
            ),

            const SizedBox(height: 16),
            Text(
              'THE DREAM IS FROZEN.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white24,
                letterSpacing: 2,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioToggle({
    required IconData icon,
    required String label,
    required bool isMuted,
    required VoidCallback onTap,
  }) {
    return GlassButton(
      width: 120,
      height: 80,
      borderRadius: 16,
      onTap: onTap,
      glowColor: isMuted ? Colors.white24 : Colors.cyanAccent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isMuted ? Colors.white24 : Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isMuted ? Colors.white24 : Colors.white70,
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
