import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'liquid_glass_dialog.dart';
import 'game_widgets.dart';

class ProfileDialog extends StatefulWidget {
  final VoidCallback onLogoutRequested;

  const ProfileDialog({
    super.key,
    required this.onLogoutRequested,
  });

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  // List of available profile images - same approach as shop
  static final List<String> _profileOptions = [
    'assets/images/core/splash_logo.png',
    'assets/images/auth/login_logo.png',
    'assets/images/auth/register_logo.png',
    // Add more paths here as needed
  ];

  late String _selectedProfileImage;

  @override
  void initState() {
    super.initState();
    // Default to splash logo if none exists
    _selectedProfileImage = _profileOptions[0];
  }

  void _showImageSelector() {
    showDialog(
      context: context,
      builder: (context) => LiquidGlassDialog(
        width: 320,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Choose Avatar', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white70, size: 20)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _profileOptions.length,
                itemBuilder: (context, index) {
                  final path = _profileOptions[index];
                  final isSelected = _selectedProfileImage == path;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedProfileImage = path);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.purpleAccent : Colors.white12,
                          width: isSelected ? 2 : 1,
                        ),
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(path, fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final String displayName = user?.displayName ?? 'Dreamer';

    return LiquidGlassDialog(
      width: 350,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Player Profile', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: _showImageSelector,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.purpleAccent, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purpleAccent.withValues(alpha: 0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      _selectedProfileImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle),
                child: const Icon(Icons.edit, size: 16, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          if (user?.email != null) Text(user!.email!, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 24),
          const StatRow(icon: Icons.bolt, label: 'Level 1', color: Colors.blueAccent),
          const SizedBox(height: 12),
          const StatRow(icon: Icons.military_tech, label: '0 XP', color: Colors.orangeAccent),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await AuthService().signOut();
                widget.onLogoutRequested();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
