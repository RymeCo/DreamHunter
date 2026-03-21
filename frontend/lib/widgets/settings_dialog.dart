import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/offline_cache.dart';
import '../services/backend_service.dart';
import 'liquid_glass_dialog.dart';
import 'custom_snackbar.dart';

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
        'Please log in to use this feature! Use the top right ☰ menu.',
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SETTINGS',
                  style: GoogleFonts.oswald(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 20),
            _buildSettingSwitch(
              title: 'Music',
              subtitle: 'Atmospheric background tracks',
              value: _musicEnabled,
              onChanged: (val) {
                setState(() => _musicEnabled = val);
                _updateSettings();
              },
            ),
            _buildSettingSwitch(
              title: 'Sound Effects',
              subtitle: 'Button clicks & game feedback',
              value: _sfxEnabled,
              onChanged: (val) {
                setState(() => _sfxEnabled = val);
                _updateSettings();
              },
            ),
            
            const SizedBox(height: 16),
            const Divider(color: Colors.white24, height: 10),
            const SizedBox(height: 8),
            
            // Cloud Sync Section
            Row(
              children: [
                const Icon(Icons.cloud_sync_rounded, color: Colors.cyanAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'CLOUD SYNC',
                  style: GoogleFonts.oswald(
                    color: Colors.cyanAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _isSyncing ? null : _performManualSync,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: _isSyncing 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
                    : Text(
                        'BACKUP DATA TO CLOUD',
                        style: GoogleFonts.oswald(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last sync: Just now or never',
              style: GoogleFonts.openSans(color: Colors.white24, fontSize: 10),
            ),
            
            const SizedBox(height: 24),
            Text(
              'V 0.1.0',
              style: GoogleFonts.openSans(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
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
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: GoogleFonts.oswald(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.openSans(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.cyanAccent,
        activeTrackColor: Colors.cyanAccent.withValues(alpha: 0.3),
        inactiveThumbColor: Colors.white24,
        inactiveTrackColor: Colors.black26,
      ),
    );
  }
}
