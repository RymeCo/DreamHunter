import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../services/admin_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/player_actions_dialog.dart';
import '../widgets/admin_ui_components.dart';

class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key});

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _msgController = TextEditingController();

  String _selectedRegion = 'english';
  final List<String> _regions = [
    'english',
    'spanish',
    'chinese',
    'russian',
    'tagalog',
    'mod-only'
  ];

  bool _isGhostMode = false;
  String _ghostName = '';

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    bool success;
    if (_isGhostMode) {
      if (_ghostName.isEmpty) {
        final name = await _askForGhostName();
        if (name == null || name.isEmpty) return;
        _ghostName = name;
      }
      success = await _adminService.sendGhostMessage(
        _selectedRegion,
        text,
        _ghostName,
      );
    } else {
      success = await _adminService.sendSystemBroadcastToChat(
        _selectedRegion,
        text,
      );
    }

    if (mounted) {
      if (success) {
        _msgController.clear();
      } else {
        showCustomSnackBar(context, 'Failed to send message.',
            type: SnackBarType.error);
      }
    }
  }

  Future<String?> _askForGhostName() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF07070F),
        title: const Text('Ghost Display Name', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
        content: AdminTextField(
          label: 'Ghost Name',
          hint: 'e.g. Mysterious Traveler',
          onSubmitted: (val) => Navigator.pop(context, val),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          AdminButton(
            onPressed: () => Navigator.pop(context, ''), // Handled by controller if needed, but here we just pop
            label: 'SET NAME',
          ),
        ],
      ),
    );
  }

  void _openPlayerActions(String uid) async {
    if (uid == 'SYSTEM_AUTOMOD' || uid.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final profile = await _adminService.getUserProfile(uid);
    if (!mounted) return;
    Navigator.pop(context);

    if (profile != null) {
      await showDialog(
        context: context,
        builder: (context) => PlayerActionsDialog(player: profile),
      );
    }
  }

  void _quickMute(String uid, int hours) async {
    final success = await _adminService.muteUser(uid, hours);
    if (success && mounted) {
      showCustomSnackBar(context, 'Player muted for ${hours}h', type: SnackBarType.success);
    }
  }

  void _quickWarn(String uid) async {
    final success = await _adminService.warnUser(uid, 'Chat Behavior Violation (Quick Warn)');
    if (success && mounted) {
      showCustomSnackBar(context, 'Warning issued!', type: SnackBarType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AdminProvider>(context);

    return StreamBuilder<DocumentSnapshot>(
      stream: _adminService.getAutoModConfigStream(),
      builder: (context, configSnapshot) {
        final modConfig = configSnapshot.data?.data() as Map<String, dynamic>? ?? {};

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminHeader(
              title: 'Moderator Hub',
              actions: [
                _buildGhostModeToggle(),
                const SizedBox(width: 16),
                _buildRegionSelector(),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AdminCard(
                  padding: EdgeInsets.zero,
                  child: _buildChatStream(modConfig, provider),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: _buildInputArea(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGhostModeToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('GHOST MODE', style: TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
        Switch(
          value: _isGhostMode,
          onChanged: (val) async {
            if (val && _ghostName.isEmpty) {
              final name = await _askForGhostName();
              if (name == null || name.isEmpty) return;
              setState(() {
                _ghostName = name;
                _isGhostMode = true;
              });
            } else {
              setState(() => _isGhostMode = val);
            }
          },
          activeThumbColor: Colors.amberAccent,
        ),
      ],
    );
  }

  Widget _buildRegionSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRegion,
          dropdownColor: const Color(0xFF07070F),
          items: _regions
              .map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(r.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: r == 'mod-only' ? Colors.purpleAccent : Colors.white70,
                      ))))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedRegion = val);
          },
        ),
      ),
    );
  }

  Widget _buildChatStream(Map<String, dynamic> modConfig, AdminProvider provider) {
    return StreamBuilder<QuerySnapshot>(
      stream: _adminService.getLiveChatStream(_selectedRegion),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No activity in this channel.', style: TextStyle(color: Colors.white12)));
        }

        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final messageId = docs[index].id;
            final text = data['text'] ?? '';
            final senderName = data['senderName'] ?? 'Unknown';
            final senderUid = data['senderUid'] ?? '';
            final isSystem = data['isSystemWarning'] == true || data['isAdmin'] == true;
            final adminDisliked = data['adminDisliked'] == true;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: isSystem ? null : () => _openPlayerActions(senderUid),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSystem ? Colors.redAccent.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(senderName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: isSystem ? Colors.redAccent : Colors.cyanAccent,
                                    )),
                                if (!isSystem && senderUid.isNotEmpty)
                                  _quickActionsRow(senderUid, messageId, adminDisliked),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(text,
                                style: TextStyle(
                                  color: isSystem ? Colors.orangeAccent : Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _quickActionsRow(String uid, String messageId, bool isHidden) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _miniActionBtn(Icons.volume_off_rounded, Colors.orangeAccent, () => _quickMute(uid, 1), 'Mute 1h'),
        _miniActionBtn(Icons.warning_amber_rounded, Colors.yellowAccent, () => _quickWarn(uid), 'Warn'),
        _miniActionBtn(isHidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            isHidden ? Colors.greenAccent : Colors.redAccent, () {
          _adminService.toggleDislikeMessage(_selectedRegion, messageId, currentDisliked: isHidden);
        }, isHidden ? 'Show' : 'Hide'),
      ],
    );
  }

  Widget _miniActionBtn(IconData icon, Color color, VoidCallback onTap, String tooltip) {
    return IconButton(
      icon: Icon(icon, size: 14, color: color.withValues(alpha: 0.4)),
      onPressed: onTap,
      tooltip: tooltip,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildInputArea() {
    return Row(
      children: [
        Expanded(
          child: AdminTextField(
            controller: _msgController,
            label: _isGhostMode ? 'GHOST CHAT AS $_ghostName' : 'SYSTEM BROADCAST',
            hint: 'Type message...',
            prefixIcon: _isGhostMode ? Icons.visibility_off_rounded : Icons.campaign_rounded,
            onSubmitted: (_) => _sendMessage(),
          ),
        ),
        const SizedBox(width: 16),
        AdminButton(
          onPressed: _sendMessage,
          label: 'SEND',
          icon: Icons.send_rounded,
          color: _isGhostMode ? Colors.orangeAccent : Colors.amberAccent,
        ),
      ],
    );
  }
}
