import 'package:dreamhunter/widgets/confirmation_dialog.dart';
import 'package:dreamhunter/widgets/branding/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/ad_manager.dart';
import 'package:dreamhunter/services/core/haptic_manager.dart';
import 'package:dreamhunter/core/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';
import 'package:dreamhunter/services/identity/profile_manager.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:dreamhunter/widgets/common_ui.dart';

class SettingsDialog extends StatefulWidget {
  final VoidCallback? onLoginRequested;
  const SettingsDialog({super.key, this.onLoginRequested});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  bool _isLoading = true;
  bool _isSyncing = false;
  int _syncCount = 0;
  final AudioManager _audioService = AudioManager();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadSyncCount();
  }

  Future<void> _loadSyncCount() async {
    final count = await StorageEngine.instance.getDailyCount('cloud_sync');
    if (mounted) setState(() => _syncCount = count);
  }

  Future<void> _loadSettings() async {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSettings() async {
    await StorageEngine.instance.saveSettings({
      'music': !_audioService.isMusicMuted,
      'sfx': !_audioService.isSoundMuted,
      'musicVolume': _audioService.musicVolume,
      'sfxVolume': _audioService.soundVolume,
      'haptics': HapticManager().isHapticEnabled,
      'pillarboxColor': 'black',
    });
  }

  void _showAboutDialog() {
    showGeneralDialog(
      context: context,
      barrierLabel: "AboutDialog",
      barrierDismissible: true,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StandardGlassPage(
          title: 'ABOUT DREAMHUNTER',
          width: 340,
          height: 520,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 32),
                // Hero Branding Section
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withValues(alpha: 0.1),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const AppLogo(size: 110),
                ),
                const SizedBox(height: 24),
                Text(
                  'DREAMHUNTER',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    letterSpacing: 8,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.cyanAccent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    'VERSION 1.0.0',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.cyanAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Game Vision Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        'THE VISION',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.cyanAccent.withValues(alpha: 0.5),
                          letterSpacing: 4,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Step into a world where dreams and nightmares collide. DreamHunter is a high-octane dark fantasy survival experience, blending pixel-perfect retro aesthetics with modern atmospheric depth.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Studio Branding Section
                Text(
                  'DEVELOPED BY',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white24,
                    letterSpacing: 3,
                    fontSize: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'RYME',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '© 2026 RYME STUDIOS',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.1),
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _performManualSync() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showCustomSnackBar(
        context,
        'Log in to backup your data!',
        type: SnackBarType.info,
      );
      return;
    }

    if (_syncCount >= 1) {
      final confirmed = await ConfirmationDialog.show(
        context,
        title: 'OVERWRITE CLOUD?',
        message:
            'Your current progress will replace the existing cloud backup. This cannot be undone.\n\nWatch a short ad to proceed.',
        confirmLabel: 'WATCH AD & OVERWRITE',
        isDestructive: true,
      );
      if (!confirmed || !mounted) return;

      AdManager.instance.showRewardAd(
        context: context,
        onRewardEarned: () async {
          await _executeSync();
        },
      );
    } else {
      final confirmed = await ConfirmationDialog.show(
        context,
        title: 'SYNC TO CLOUD?',
        message:
            'Any existing cloud data will be deleted and replaced with your current local progress.',
        confirmLabel: 'BACKUP NOW',
        color: Colors.cyanAccent,
      );
      if (!confirmed || !mounted) return;

      await _executeSync();
    }
  }

  Future<void> _executeSync() async {
    setState(() => _isSyncing = true);
    try {
      await ProfileManager.instance.backupPlayer();
      await StorageEngine.instance.incrementDailyCount('cloud_sync');
      await _loadSyncCount();
      if (mounted) {
        showCustomSnackBar(
          context,
          'Cloud sync successful!',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(
          context,
          'Sync failed. Check your connection.',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return StandardGlassPage(
      title: 'SETTINGS',
      isFullScreen: true,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildSectionLabel(context, 'SENSORY CONTROLS'),
            _buildGlassBlock(
              context,
              accentColor: Colors.cyanAccent,
              children: [
                _GlassSettingItem(
                  title: 'Music',
                  subtitle: 'Ambient background themes',
                  icon: Icons.music_note_rounded,
                  value: !_audioService.isMusicMuted,
                  accentColor: Colors.cyanAccent,
                  onChanged: (val) async {
                    await _audioService.toggleMusicMute();
                    await _updateSettings();
                    if (mounted) setState(() {});
                  },
                  sliderValue: _audioService.musicVolume,
                  onSliderChanged: (val) {
                    _audioService.setMusicVolume(val);
                    if (mounted) setState(() {});
                  },
                  onSliderChangeEnd: () => _updateSettings(),
                ),
                _buildDivider(),
                _GlassSettingItem(
                  title: 'Sound',
                  subtitle: 'Interaction & combat effects',
                  icon: Icons.volume_up_rounded,
                  value: !_audioService.isSoundMuted,
                  accentColor: Colors.cyanAccent,
                  onChanged: (val) async {
                    await _audioService.toggleSoundMute();
                    await _updateSettings();
                    if (mounted) setState(() {});
                  },
                  sliderValue: _audioService.soundVolume,
                  onSliderChanged: (val) {
                    _audioService.setSoundVolume(val);
                    if (mounted) setState(() {});
                  },
                  onSliderChangeEnd: () async {
                    await _updateSettings();
                    _audioService.playClick();
                  },
                ),
                _buildDivider(),
                _GlassSettingItem(
                  title: 'Haptic Feedback',
                  subtitle: 'Tactile response on interaction',
                  icon: Icons.vibration_rounded,
                  value: HapticManager().isHapticEnabled,
                  accentColor: Colors.cyanAccent,
                  onChanged: (val) async {
                    await HapticManager().toggleHaptics();
                    await _updateSettings();
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionLabel(context, 'CORE SYSTEM'),
            _buildGlassBlock(
              context,
              accentColor: Colors.deepPurpleAccent,
              children: [
                _GlassActionItem(
                  title: 'Cloud Storage Sync',
                  subtitle: _isSyncing
                      ? 'Syncing...'
                      : (_syncCount >= 1
                            ? 'Watch Ad to Sync again'
                            : 'Backup your progress ($_syncCount/1)'),
                  icon: Icons.cloud_done_rounded,
                  accentColor: Colors.cyanAccent,
                  onTap: _isSyncing ? () {} : _performManualSync,
                  trailing: _isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.cyanAccent,
                          ),
                        )
                      : null,
                ),
                _buildDivider(),
                _GlassActionItem(
                  title: 'Support the Dev',
                  subtitle: 'Keep the servers alive',
                  icon: Icons.volunteer_activism_rounded,
                  accentColor: Colors.pinkAccent,
                  onTap: () {
                    showCustomSnackBar(
                      context,
                      'Donation links coming soon!',
                      type: SnackBarType.success,
                    );
                  },
                ),
                _buildDivider(),
                _GlassActionItem(
                  title: 'About DreamHunter',
                  subtitle: 'V1.0.2 • Project Credits',
                  icon: Icons.info_outline_rounded,
                  accentColor: Colors.deepPurpleAccent,
                  onTap: _showAboutDialog,
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'DREAMHUNTER V 1.0.0',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.15),
                fontSize: 10,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 10,
            letterSpacing: 2.5,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassBlock(
    BuildContext context, {
    required List<Widget> children,
    required Color accentColor,
  }) {
    final glassTheme =
        Theme.of(context).extension<GlassTheme>() ?? const GlassTheme();
    const double radius = 24.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: glassTheme.baseOpacity * 0.2),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: glassTheme.borderAlpha * 0.25),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(children.length, (index) {
          final child = children[index];
          if (child is _GlassSettingItem || child is _GlassActionItem) {
            final isFirst = index == 0;
            final isLast = index == children.length - 1;
            final borderRadius = BorderRadius.vertical(
              top: isFirst ? const Radius.circular(radius) : Radius.zero,
              bottom: isLast ? const Radius.circular(radius) : Radius.zero,
            );

            if (child is _GlassSettingItem) {
              return child.copyWith(borderRadius: borderRadius);
            } else if (child is _GlassActionItem) {
              return child.copyWith(borderRadius: borderRadius);
            }
          }
          return child;
        }),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 60,
      color: Colors.white.withValues(alpha: 0.03),
    );
  }
}

class _GlassSettingItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accentColor;
  final double? sliderValue;
  final ValueChanged<double>? onSliderChanged;
  final VoidCallback? onSliderChangeEnd;
  final BorderRadius borderRadius;

  const _GlassSettingItem({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.accentColor,
    this.sliderValue,
    this.onSliderChanged,
    this.onSliderChangeEnd,
    this.borderRadius = BorderRadius.zero,
  });

  _GlassSettingItem copyWith({BorderRadius? borderRadius}) {
    return _GlassSettingItem(
      title: title,
      subtitle: subtitle,
      icon: icon,
      value: value,
      onChanged: onChanged,
      accentColor: accentColor,
      sliderValue: sliderValue,
      onSliderChanged: onSliderChanged,
      onSliderChangeEnd: onSliderChangeEnd,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final glassTheme =
        Theme.of(context).extension<GlassTheme>() ?? const GlassTheme();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticManager().light();
          onChanged(!value);
        },
        hoverColor: accentColor.withValues(alpha: glassTheme.baseOpacity / 2),
        splashColor: accentColor.withValues(alpha: glassTheme.baseOpacity),
        highlightColor: accentColor.withValues(alpha: glassTheme.baseOpacity),
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: glassTheme.baseOpacity / 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white70, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontSize: 14),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white38, fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: value,
                      onChanged: (v) {
                        HapticManager().light();
                        onChanged(v);
                      },
                      activeThumbColor: accentColor,
                      activeTrackColor: accentColor.withValues(alpha: 0.2),
                      inactiveThumbColor: Colors.white24,
                      inactiveTrackColor: Colors.white10,
                      trackOutlineColor: WidgetStateProperty.all(
                        Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
              if (value && sliderValue != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 44, right: 8),
                  child: SizedBox(
                    height: 24,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        activeTrackColor: accentColor.withValues(alpha: 0.4),
                        inactiveTrackColor: Colors.white10,
                        thumbColor: accentColor,
                      ),
                      child: Slider(
                        value: sliderValue!,
                        onChanged: onSliderChanged,
                        onChangeEnd: onSliderChangeEnd != null
                            ? (_) => onSliderChangeEnd!()
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassActionItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final Widget? trailing;
  final BorderRadius borderRadius;

  const _GlassActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.trailing,
    this.borderRadius = BorderRadius.zero,
  });

  _GlassActionItem copyWith({BorderRadius? borderRadius}) {
    return _GlassActionItem(
      title: title,
      subtitle: subtitle,
      icon: icon,
      accentColor: accentColor,
      onTap: onTap,
      trailing: trailing,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final glassTheme =
        Theme.of(context).extension<GlassTheme>() ?? const GlassTheme();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticManager().light();
          onTap();
        },
        hoverColor: accentColor.withValues(alpha: glassTheme.baseOpacity / 2),
        splashColor: accentColor.withValues(alpha: glassTheme.baseOpacity),
        highlightColor: accentColor.withValues(alpha: glassTheme.baseOpacity),
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: glassTheme.baseOpacity / 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white70, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontSize: 14),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white24,
                  size: 14,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
