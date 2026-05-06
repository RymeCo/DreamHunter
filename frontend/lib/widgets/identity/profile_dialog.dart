import 'package:flutter/material.dart';
import 'package:dreamhunter/services/core/ad_manager.dart';
import 'package:dreamhunter/services/identity/auth_manager.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';
import 'package:dreamhunter/services/identity/profile_manager.dart';
import 'package:dreamhunter/services/progression/progression_manager.dart';
import 'package:dreamhunter/widgets/confirmation_dialog.dart';
import 'package:dreamhunter/widgets/custom_snackbar.dart';
import 'package:dreamhunter/widgets/common_ui.dart';
import 'package:dreamhunter/models/player_model.dart';

class ProfileDialog extends StatefulWidget {
  final VoidCallback onLogoutRequested;

  const ProfileDialog({super.key, required this.onLogoutRequested});

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  PlayerModel? _player;
  String _levelRank = '??';
  String _coinsRank = '??';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    // Reload user to get latest verification status
    await AuthManager.instance.reloadUser();

    final player = await ProfileManager.instance.getPlayer();
    final ranks = await ProfileManager.instance.getLeaderboardRank();

    if (mounted) {
      setState(() {
        _player = player;
        _levelRank = ranks['levelRank'] ?? '??';
        _coinsRank = ranks['coinsRank'] ?? '??';
      });
    }
  }

  void _resendVerification() async {
    try {
      await AuthManager.instance.sendEmailVerification();
      if (mounted) {
        showCustomSnackBar(
          context,
          'Verification resent! Please check your Spam or All Mail folders.',
          type: SnackBarType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(
          context,
          'Failed to resend email.',
          type: SnackBarType.error,
        );
      }
    }
  }

  void _refreshVerification() async {
    setState(() => _player = null); // Show loading state briefly
    await _fetchData();
    if (mounted) {
      final user = AuthManager().currentUser;
      if (user?.emailVerified ?? false) {
        showCustomSnackBar(
          context,
          'Account successfully verified!',
          type: SnackBarType.info,
        );
      } else {
        showCustomSnackBar(
          context,
          'Still unverified. Did you click the link in your email?',
          type: SnackBarType.info,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthManager().currentUser;
    final String displayName = user?.displayName ?? 'Dreamer';
    final String? email = user?.email;

    return ListenableBuilder(
      listenable: ProgressionManager.instance,
      builder: (context, child) {
        final prog = ProgressionManager.instance;

        return StandardGlassPage(
          title: 'PLAYER PROFILE',
          isFullScreen: true,
          footer: [
            // Backup Section
            _buildBackupSection(context),
            const SizedBox(height: 12),
            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  AudioManager().playClick();
                  Navigator.pop(context);
                  await ProfileManager.instance.logout();
                  widget.onLogoutRequested();
                },
                icon: const Icon(Icons.logout, size: 16),
                label: Text(
                  'LOGOUT SESSION',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    letterSpacing: 2,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                // Professional Profile Avatar (Synced with HUD)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black45,
                        border: Border.all(
                          color: Colors.blueAccent.withValues(alpha: 0.5),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withValues(alpha: 0.2),
                            blurRadius: 25,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const ClipOval(
                        child: Image(
                          image: AssetImage(
                            'assets/images/dashboard/profile.png',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (_player?.isBannedPermanent ?? false)
                      _buildStatusBadge('BANNED', Colors.red),
                    if (_player?.isMuted ?? false)
                      _buildStatusBadge('MUTED', Colors.orange),
                  ],
                ),

                const SizedBox(height: 16),

                // Player Identity
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      displayName.toUpperCase(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    if (user?.emailVerified ?? false) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Account verified and tied to $email',
                        child: GestureDetector(
                          onTap: () {
                            showCustomSnackBar(
                              context,
                              'Verified account tied to $email',
                              type: SnackBarType.info,
                            );
                          },
                          child: const Icon(
                            Icons.verified,
                            color: Colors.cyanAccent,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (email != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white38,
                          letterSpacing: 1.1,
                          fontSize: 11,
                        ),
                      ),
                      if (!(user?.emailVerified ?? false)) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _resendVerification,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'RESEND',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '•',
                          style: TextStyle(color: Colors.white24, fontSize: 9),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: _refreshVerification,
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.cyanAccent,
                            size: 14,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Refresh Status',
                        ),
                      ],
                    ],
                  ),
                ],
                if (_player != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'MEMBERSHIP SINCE ${_formatDate(_player!.createdAt)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white10,
                      fontSize: 8,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Stats & Ranking Module
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildStatRow(
                        context,
                        icon: Icons.bolt,
                        label: 'Level',
                        value: '${prog.level}',
                        rank: _levelRank,
                        color: Colors.cyanAccent,
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 12),
                      _buildStatRow(
                        context,
                        icon: Icons.monetization_on,
                        label: 'Total Coins',
                        value: '${_player?.coins ?? 0}',
                        rank: _coinsRank,
                        color: Colors.amberAccent,
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 12),
                      _buildStatRow(
                        context,
                        icon: Icons.military_tech,
                        label: 'Progression',
                        value: '${prog.xp} / ${prog.xpThreshold} XP',
                        color: Colors.orangeAccent,
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: prog.progress,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.cyanAccent,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    String? rank,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white54,
                letterSpacing: 1.2,
              ),
            ),
            if (rank != null)
              Text(
                'Rank: $rank / 50',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: rank == '??'
                      ? Colors.white24
                      : color.withValues(alpha: 0.7),
                  fontSize: 9,
                ),
              ),
          ],
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Positioned(
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildBackupSection(BuildContext context) {
    return FutureBuilder<int>(
      future: StorageEngine.instance.getDailyCount('cloud_sync'),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final bool isLimitReached = count >= 1;
        final user = AuthManager().currentUser;
        final bool isGuest = user == null;
        final bool isVerified = user?.emailVerified ?? false;

        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (isGuest || !isVerified)
                    ? null
                    : () async {
                        AudioManager().playClick();

                        final confirmed = await ConfirmationDialog.show(
                          context,
                          title: isLimitReached
                              ? 'OVERWRITE CLOUD?'
                              : 'SYNC TO CLOUD?',
                          message:
                              'Any existing cloud data will be deleted and replaced with your current local progress. This cannot be undone.${isLimitReached ? '\n\nWatch a short ad to proceed.' : ''}',
                          confirmLabel: isLimitReached
                              ? 'WATCH AD & OVERWRITE'
                              : 'BACKUP NOW',
                          isDestructive: isLimitReached,
                          color: isLimitReached ? null : Colors.cyanAccent,
                        );
                        if (!confirmed || !context.mounted) return;

                        if (isLimitReached) {
                          AdManager.instance.showRewardAd(
                            context: context,
                            onRewardEarned: () async {
                              await ProfileManager.instance.backupPlayer();
                              await StorageEngine.instance.incrementDailyCount(
                                'cloud_sync',
                              );
                              if (mounted) setState(() {});
                            },
                          );
                        } else {
                          await ProfileManager.instance.backupPlayer();
                          await StorageEngine.instance.incrementDailyCount(
                            'cloud_sync',
                          );
                          if (mounted) setState(() {});
                        }
                      },
                icon: Icon(
                  isLimitReached ? Icons.play_circle_fill : Icons.cloud_upload,
                ),
                label: Text(
                  isLimitReached
                      ? 'WATCH AD FOR BACKUP'
                      : 'BACKUP TO CLOUD ($count/1)',
                  style: const TextStyle(letterSpacing: 2),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: isLimitReached
                      ? Colors.orangeAccent.withValues(alpha: 0.1)
                      : Colors.cyanAccent.withValues(alpha: 0.1),
                  foregroundColor: isLimitReached
                      ? Colors.orangeAccent
                      : Colors.cyanAccent,
                  side: BorderSide(
                    color: isLimitReached
                        ? Colors.orangeAccent.withValues(alpha: 0.3)
                        : Colors.cyanAccent.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (isGuest)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'LOG IN TO BACKUP PROGRESS',
                  style: TextStyle(color: Colors.white24, fontSize: 9),
                ),
              )
            else if (!isVerified)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'VERIFY EMAIL TO ENABLE BACKUP',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 9),
                ),
              ),
          ],
        );
      },
    );
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '??-??-??';
    try {
      final date = DateTime.parse(iso);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return iso;
    }
  }
}
