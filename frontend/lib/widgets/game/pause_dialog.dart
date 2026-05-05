import 'package:flutter/material.dart';
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
    return StandardGlassPage(
      title: 'PAUSED',
      isCentered: true,
      isCompact: true,
      width: 240,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      footer: [
        GlassButton(
          label: 'RESUME',
          width: double.infinity,
          height: 40,
          borderRadius: 10,
          glowColor: Colors.cyanAccent,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(height: 10),
        GlassButton(
          label: 'QUIT GAME',
          width: double.infinity,
          height: 36,
          borderRadius: 10,
          glowColor: Colors.redAccent,
          hoverColor: Colors.redAccent.withValues(alpha: 0.15),
          hoverBorderColor: Colors.redAccent,
          hoverTextColor: Colors.redAccent,
          onTap: () {
            // Return 'quit' to the caller (GameScreen) to trigger the Reward Screen
            Navigator.pop(context, 'quit');
          },
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'THE DREAM IS FROZEN.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white24,
              letterSpacing: 2,
              fontSize: 8,
            ),
          ),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              const SizedBox(width: 12),
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
          const SizedBox(height: 8),
        ],
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
      width: 90,
      height: 60,
      borderRadius: 12,
      onTap: onTap,
      glowColor: isMuted ? Colors.white10 : Colors.white30,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isMuted ? Colors.white24 : Colors.white70,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isMuted ? Colors.white12 : Colors.white54,
              fontSize: 8,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
