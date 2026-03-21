import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../services/offline_cache.dart';
import 'liquid_glass_dialog.dart';
import 'custom_snackbar.dart';

class ProfileDialog extends StatefulWidget {
  final BackendService backendService;
  final VoidCallback onLogoutRequested;

  const ProfileDialog({
    super.key,
    required this.backendService,
    required this.onLogoutRequested,
  });

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  final List<String> _predefinedAvatars = [
    'assets/images/dashboard/profile.png',
    'assets/images/dashboard/profile_logo.png',
    'assets/images/dashboard/small_circle_figure.png',
    'assets/images/dashboard/roulette_man.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final data = await OfflineCache.getCurrency();
    if (mounted) {
      setState(() {
        _userData = data;
        _isLoading = false;
      });
    }
  }

  void _showAvatarSelection() {
    showGeneralDialog(
      context: context,
      barrierLabel: "AvatarSelection",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: ScaleTransition(
            scale: animation,
            child: LiquidGlassDialog(
              width: 350,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Avatar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _predefinedAvatars.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);
                          await _updateAvatar(index);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (_userData?['avatarId'] ?? 0) == index
                                  ? Colors.blueAccent
                                  : Colors.white24,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            backgroundColor: Colors.white10,
                            backgroundImage: AssetImage(_predefinedAvatars[index]),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateAvatar(int id) async {
    setState(() => _isLoading = true);
    final success = await widget.backendService.updateAvatar(id);
    if (success) {
      final current = await OfflineCache.getCurrency();
      await OfflineCache.saveCurrency(
        current['dreamCoins']!,
        current['hellStones']!,
        current['playtime']!,
        current['freeSpins']!,
        current['xp']!,
        current['level']!,
        id,
      );
      await _loadUserData();
      if (mounted) {
        showCustomSnackBar(context, 'Avatar updated!', type: SnackBarType.success);
      }
    } else {
      if (mounted) {
        showCustomSnackBar(context, 'Failed to update avatar.', type: SnackBarType.error);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final String displayName = user?.displayName ?? 'Dreamer';
    final int avatarId = _userData?['avatarId'] ?? 0;
    final String avatarPath = avatarId < _predefinedAvatars.length 
        ? _predefinedAvatars[avatarId] 
        : _predefinedAvatars[0];

    return LiquidGlassDialog(
      width: 350,
      padding: const EdgeInsets.all(24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Player Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _showAvatarSelection,
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.black26,
                        backgroundImage: AssetImage(avatarPath),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (user?.email != null)
                Text(
                  user!.email!,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              const SizedBox(height: 24),
              _buildStatRow(Icons.bolt, 'Level ${_userData?['level'] ?? 1}', Colors.blueAccent),
              const SizedBox(height: 12),
              _buildStatRow(Icons.military_tech, '${_userData?['xp'] ?? 0} XP', Colors.orangeAccent),
              const SizedBox(height: 12),
              _buildStatRow(Icons.timer_rounded, _formatPlaytime((_userData?['playtime'] ?? 0) as int), Colors.greenAccent),
              if (_userData?['createdAt'] != null) ...[
                const SizedBox(height: 12),
                _buildStatRow(
                  Icons.calendar_month_rounded,
                  'Member since ${_formatDate(_userData!['createdAt'])}',
                  Colors.purpleAccent,
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    showCustomSnackBar(context, 'Logging out...', type: SnackBarType.info);
                    await AuthService().signOut();
                    widget.onLogoutRequested();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.redAccent, width: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            ),
        ],
      ),
    );
  }

  String _formatPlaytime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m playtime';
    } else {
      return '${minutes}m playtime';
    }
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildStatRow(IconData icon, String label, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
