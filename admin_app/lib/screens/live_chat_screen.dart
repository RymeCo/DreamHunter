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
    String name = '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E3A),
        title: const Text('Enter Ghost Display Name'),
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
            onPressed: () => Navigator.pop(context, name),
            label: 'SET NAME',
          ),
        ],
      ),
    );
  }

  void _openPlayerActions(String uid, Map<String, dynamic> modConfig) async {
    if (uid == 'SYSTEM_AUTOMOD' || uid.isEmpty) return;

    final provider = Provider.of<AdminProvider>(context, listen: false);
    final isMod = provider.isModerator && !provider.isAdmin;

    if (isMod) {
      final canMute = modConfig['modCanMute'] ?? true;
      final canWarn = modConfig['modCanWarn'] ?? true;
      if (!canMute && !canWarn) {
        showCustomSnackBar(context, 'Insufficient permissions.',
            type: SnackBarType.info);
        return;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final profile = await _adminService.getUserProfile(uid);
    if (!mounted) return;
    Navigator.pop(context);

    if (profile != null) {
      await showDialog<String>(
        context: context,
        builder: (context) => PlayerActionsDialog(player: profile),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AdminProvider>(context);

    return StreamBuilder<DocumentSnapshot>(
      stream: _adminService.getAutoModConfigStream(),
      builder: (context, configSnapshot) {
        final modConfig =
            configSnapshot.data?.data() as Map<String, dynamic>? ?? {};

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminHeader(
              title: 'Live Chat Monitor',
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
        const Text('GHOST MODE',
            style: TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
        color: const Color(0xFF0F0F1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRegion,
          dropdownColor: const Color(0xFF1E1E3A),
          items: _regions
              .map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(r.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedRegion = val);
          },
        ),
      ),
    );
  }

  Widget _buildChatStream(
      Map<String, dynamic> modConfig, AdminProvider provider) {
    return StreamBuilder<QuerySnapshot>(
      stream: _adminService.getLiveChatStream(_selectedRegion),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
              child: Text('Quiet in here...',
                  style: TextStyle(color: Colors.white12)));
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
            final isAdminMsg = data['isAdmin'] == true;
            final isSystem = data['isSystemWarning'] == true || isAdminMsg;
            final adminDisliked = data['adminDisliked'] == true;
            final adminLiked = data['adminLiked'] == true;

            if (adminDisliked && !provider.isAdmin && !provider.isModerator) {
              return const SizedBox.shrink();
            }

            return RepaintBoundary(
              key: ValueKey(messageId),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: isSystem
                            ? null
                            : () => _openPlayerActions(senderUid, modConfig),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSystem
                                ? Colors.redAccent.withValues(alpha: 0.1)
                                : const Color(0xFF0F0F1E),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: adminLiked
                                  ? Colors.amberAccent.withValues(alpha: 0.5)
                                  : const Color(0xFF2A2A4A),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                senderName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: isSystem
                                      ? Colors.redAccent
                                      : Colors.blueAccent,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                text,
                                style: TextStyle(
                                  color: isSystem
                                      ? Colors.yellowAccent
                                          .withValues(alpha: 0.9)
                                      : Colors.white.withValues(alpha: 0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _chatActions(messageId, data, provider, modConfig),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _chatActions(String messageId, Map<String, dynamic> data,
      AdminProvider provider, Map<String, dynamic> modConfig) {
    final adminLiked = data['adminLiked'] == true;
    final modLiked = data['modLiked'] == true;
    final adminDisliked = data['adminDisliked'] == true;
    final isSystem = data['isSystemWarning'] == true || data['isAdmin'] == true;

    return Column(
      children: [
        IconButton(
          icon: Icon(Icons.thumb_up_rounded,
              size: 16,
              color: adminLiked
                  ? Colors.amberAccent
                  : (modLiked ? Colors.blueAccent : Colors.white10)),
          onPressed: isSystem
              ? null
              : () => _adminService.toggleLikeMessage(
                    _selectedRegion,
                    messageId,
                    isAdmin: provider.isAdmin,
                    isModerator: provider.isModerator,
                    currentAdminLiked: adminLiked,
                    currentModLiked: modLiked,
                  ),
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(8),
        ),
        if (provider.isAdmin ||
            (provider.isModerator && modConfig['modCanHideMessages'] == true))
          IconButton(
            icon: Icon(
                adminDisliked
                    ? Icons.visibility_rounded
                    : Icons.thumb_down_rounded,
                size: 16,
                color: adminDisliked ? Colors.greenAccent : Colors.redAccent.withValues(alpha: 0.2)),
            onPressed: () => _adminService.toggleDislikeMessage(
              _selectedRegion,
              messageId,
              currentDisliked: adminDisliked,
            ),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
      ],
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
          label: _isGhostMode ? 'GHOST' : 'SEND',
          color: _isGhostMode ? Colors.orangeAccent : Colors.amberAccent,
        ),
      ],
    );
  }
}
