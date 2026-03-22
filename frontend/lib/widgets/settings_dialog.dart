import 'package:flutter/material.dart';
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
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  bool _isLoading = true;
  bool _isSyncing = false;
  final BackendService _backendService = BackendService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await OfflineCache.getSettings();
    if (mounted) {
      setState(() {
        _musicEnabled = settings['music'] ?? true;
        _sfxEnabled = settings['sfx'] ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSettings() async {
    await OfflineCache.saveSettings({
      'music': _musicEnabled,
      'sfx': _sfxEnabled,
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
        showCustomSnackBar(context, 'Cloud sync successful!', type: SnackBarType.success);
      } else {
        showCustomSnackBar(context, 'Sync failed. Check your connection.', type: SnackBarType.error);
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
              value: _musicEnabled,
              onChanged: (val) {
                setState(() => _musicEnabled = val);
                _updateSettings();
              },
            ),
            const SizedBox(height: 8),
            _buildSettingSwitch(
              title: 'Sound Effects',
              subtitle: 'UI & game feedback',
              icon: Icons.volume_up_rounded,
              value: _sfxEnabled,
              onChanged: (val) {
                setState(() => _sfxEnabled = val);
                _updateSettings();
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
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
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
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.cyanAccent,
        activeTrackColor: Colors.cyanAccent.withValues(alpha: 0.3),
      ),
    );
  }
}
