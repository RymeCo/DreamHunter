import 'package:flutter/material.dart';
import 'package:dreamhunter/services/audio_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/offline_cache.dart';
import '../services/backend_service.dart';
import 'liquid_glass_dialog.dart';
import 'custom_snackbar.dart';
import 'game_widgets.dart';
import 'clickable_image.dart';

class SettingsDialog extends StatefulWidget {
  final VoidCallback? onLoginRequested;
  const SettingsDialog({super.key, this.onLoginRequested});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  bool _isLoading = true;
  bool _isSyncing = false;
  final BackendService _backendService = BackendService();
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // AudioService is already initialized with settings in main.dart
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSettings() async {
    await OfflineCache.saveSettings({
      'music': !_audioService.isMusicMuted,
      'sfx': !_audioService.isSoundMuted,
      'musicVolume': _audioService.musicVolume,
      'sfxVolume': _audioService.soundVolume,
    });
  }

  Future<void> _performManualSync() async {
    if (FirebaseAuth.instance.currentUser == null) {
      showCustomSnackBar(
        context,
        'Log in to backup your data!',
        type: SnackBarType.info,
      );
      return;
    }

    setState(() => _isSyncing = true);
    final success = await _backendService.performFullSync();

    if (mounted) {
      setState(() => _isSyncing = false);
      if (success) {
        showCustomSnackBar(
          context,
          'Cloud sync successful!',
          type: SnackBarType.success,
        );
      } else {
        showCustomSnackBar(
          context,
          'Sync failed. Check your connection.',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: LiquidGlassDialog(
        width: 350,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GameDialogHeader(title: 'Settings'),
            const SizedBox(height: 16),
            _buildSettingSwitch(
              title: 'Music',
              subtitle: 'Atmospheric background tracks',
              icon: Icons.music_note_rounded,
              value: !_audioService.isMusicMuted,
              onChanged: (val) async {
                await _audioService.toggleMusicMute();
                await _updateSettings();
                if (mounted) setState(() {});
              },
            ),
            if (!_audioService.isMusicMuted)
              _buildVolumeSlider(
                value: _audioService.musicVolume,
                onChanged: (val) {
                  _audioService.setMusicVolume(val);
                  if (mounted) setState(() {});
                },
                onChangeEnd: () => _updateSettings(),
              ),
            const SizedBox(height: 8),
            _buildSettingSwitch(
              title: 'Sound Effects',
              subtitle: 'UI & game feedback',
              icon: Icons.volume_up_rounded,
              value: !_audioService.isSoundMuted,
              onChanged: (val) async {
                await _audioService.toggleSoundMute();
                await _updateSettings();
                if (mounted) setState(() {});
              },
            ),
            if (!_audioService.isSoundMuted)
              _buildVolumeSlider(
                value: _audioService.soundVolume,
                onChanged: (val) {
                  _audioService.setSoundVolume(val);
                  if (mounted) setState(() {});
                },
                onChangeEnd: () async {
                  await _updateSettings();
                  await _audioService.playClick();
                },
              ),

            const SizedBox(height: 24),
            const StatRow(
              icon: Icons.cloud_sync_rounded,
              label: 'CLOUD SYNC',
              color: Colors.cyanAccent,
            ),
            const SizedBox(height: 12),
            GlassButton(
              onTap: _isSyncing ? null : _performManualSync,
              width: double.infinity,
              height: 55,
              color: Colors.cyanAccent.withValues(alpha: 0.1),
              borderColor: Colors.cyanAccent.withValues(alpha: 0.3),
              child: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.cyanAccent,
                      ),
                    )
                  : const Text(
                      'BACKUP DATA TO CLOUD',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        fontSize: 14,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'DREAMHUNTER V 0.1.5',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeSlider({
    required double value,
    required ValueChanged<double> onChanged,
    VoidCallback? onChangeEnd,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.volume_down, size: 16, color: Colors.white38),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Colors.cyanAccent,
                inactiveTrackColor: Colors.white10,
                thumbColor: Colors.cyanAccent,
                overlayColor: Colors.cyanAccent.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: value,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd != null ? (_) => onChangeEnd() : null,
              ),
            ),
          ),
          const Icon(Icons.volume_up, size: 16, color: Colors.white38),
        ],
      ),
    );
  }

  Widget _buildSettingSwitch({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: Colors.white70),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        value: value,
        onChanged: (val) {
          AudioService().playClick();
          onChanged(val);
        },
        activeThumbColor: Colors.cyanAccent,
        activeTrackColor: Colors.cyanAccent.withValues(alpha: 0.3),
      ),
    );
  }
}
