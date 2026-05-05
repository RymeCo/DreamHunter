import 'package:flutter/material.dart';
import 'package:dreamhunter/services/core/ad_manager.dart';
import 'package:dreamhunter/services/identity/auth_manager.dart';
import 'package:dreamhunter/services/core/audio_manager.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';
import 'package:dreamhunter/services/identity/profile_manager.dart';
import 'package:dreamhunter/services/economy/shop_manager.dart';
import 'package:dreamhunter/services/progression/progression_manager.dart';
import 'package:dreamhunter/data/item_registry.dart';
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
                          image: AssetImage('assets/images/dashboard/profile.png'),
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
                Text(
                  displayName.toUpperCase(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                ),
                if (email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white38,
                          letterSpacing: 1.1,
                          fontSize: 11,
                        ),
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
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                      color: rank == '??' ? Colors.white24 : color.withValues(alpha: 0.7),
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
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 10,
            ),
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

  Color _getStatusColor() {
    if (_player?.isBannedPermanent ?? false) return Colors.red;
    if (_player?.isMuted ?? false) return Colors.orange;
    return Colors.blueAccent;
  }

  Widget _buildBackupSection(BuildContext context) {
    return FutureBuilder<int>(
      future: StorageEngine.instance.getDailyCount('cloud_backup'),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final bool isLimitReached = count >= 1;
        final bool isGuest = AuthManager().currentUser == null;

        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isGuest ? null : () async {
                  AudioManager().playClick();
                  if (isLimitReached) {
                    AdManager.instance.showRewardAd(
                      context: context,
                      onRewardEarned: () async {
                        await ProfileManager.instance.backupPlayer();
                        if (mounted) setState(() {});
                      },
                    );
                  } else {
                    await ProfileManager.instance.backupPlayer();
                    if (mounted) setState(() {});
                  }
                },
                icon: Icon(isLimitReached ? Icons.play_circle_fill : Icons.cloud_upload),
                label: Text(
                  isLimitReached ? 'WATCH AD FOR BACKUP' : 'BACKUP TO CLOUD ($count/1)',
                  style: const TextStyle(letterSpacing: 2),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: isLimitReached ? Colors.orangeAccent.withValues(alpha: 0.1) : Colors.cyanAccent.withValues(alpha: 0.1),
                  foregroundColor: isLimitReached ? Colors.orangeAccent : Colors.cyanAccent,
                  side: BorderSide(
                    color: isLimitReached ? Colors.orangeAccent.withValues(alpha: 0.3) : Colors.cyanAccent.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (isGuest)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('LOG IN TO BACKUP PROGRESS', style: TextStyle(color: Colors.white24, fontSize: 9)),
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
