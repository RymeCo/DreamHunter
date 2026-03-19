import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/liquid_glass_dialog.dart';
import '../widgets/player_actions_dialog.dart';

class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key});

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _msgController = TextEditingController();

  String _selectedRegion = 'english';
  final List<String> _regions = ['english', 'spanish', 'portuguese', 'tagalog'];

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
      success =
          await _adminService.sendGhostMessage(_selectedRegion, text, _ghostName);
    } else {
      success =
          await _adminService.sendSystemBroadcastToChat(_selectedRegion, text);
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
        backgroundColor: const Color(0xFF16162F),
        title: const Text('Enter Ghost Display Name'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Mysterious Traveler'),
          onChanged: (val) => name = val,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, name),
            child: const Text('Set Name'),
          ),
        ],
      ),
    );
  }

  void _openPlayerActions(String uid) async {
    if (uid == 'SYSTEM_AUTOMOD' || uid.isEmpty) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final profile = await _adminService.getUserProfile(uid);

    if (!mounted) return;
    Navigator.pop(context); // Close loading indicator

    if (profile != null) {
      final action = await showDialog<String>(
        context: context,
        builder: (context) => PlayerActionsDialog(player: profile),
      );

      if (action != null && mounted) {
        // If an action was taken, we might want to announce it
        if (action == 'ban' || action == 'mute') {
          final playerName = profile['displayName'] ?? 'A player';
          final actionText = action == 'ban' ? 'banned' : 'muted';
          _adminService.sendSystemBroadcastToChat(_selectedRegion,
              '⚠️ [System: $playerName has been $actionText by an Admin for violating chat rules.]');
        }
      }
    } else {
      showCustomSnackBar(context, 'Could not load player profile.',
          type: SnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Live Chat Monitor',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                const Text('Ghost Mode', style: TextStyle(color: Colors.white70)),
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
                  activeColor: Colors.amberAccent,
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedRegion,
                  dropdownColor: const Color(0xFF16162F),
                  items: _regions
                      .map((r) =>
                          DropdownMenuItem(value: r, child: Text(r.toUpperCase())))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRegion = val);
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LiquidGlassDialog(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: _adminService.getLiveChatStream(_selectedRegion),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                return ListView.builder(
                  reverse: true, // Latest at the bottom visually
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final messageId = docs[index].id;
                    final text = data['text'] ?? '';
                    final originalText = data['originalText'];
                    final senderName = data['senderName'] ?? 'Unknown';
                    final senderUid = data['senderUid'] ?? '';
                    final isAdmin = data['isAdmin'] == true;
                    final isSystem = data['isSystemWarning'] == true || isAdmin;
                    final adminDisliked = data['adminDisliked'] == true;
                    final adminLiked = data['adminLiked'] == true;
                    final isGhost = data['isGhost'] == true;

                    if (adminDisliked) {
                      return const SizedBox
                          .shrink(); // Hide from admin stream or show tombstone
                    }

                    return InkWell(
                      onTap: isSystem ? null : () => _openPlayerActions(senderUid),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSystem
                              ? Colors.redAccent.withValues(alpha: 0.1)
                              : Colors.black26,
                          border: Border.all(
                            color: adminLiked
                                ? Colors.amberAccent
                                : (isSystem
                                    ? Colors.redAccent.withValues(alpha: 0.5)
                                    : Colors.white12),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        senderName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isSystem
                                              ? Colors.redAccent
                                              : Colors.blueAccent,
                                        ),
                                      ),
                                      if (isGhost) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.visibility_off,
                                            size: 14, color: Colors.white38),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(text,
                                      style: TextStyle(
                                          color: isSystem
                                              ? Colors.yellowAccent
                                              : Colors.white)),
                                  if (originalText != null) ...[
                                    const SizedBox(height: 4),
                                    Text('Original: $originalText',
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontStyle: FontStyle.italic,
                                            fontSize: 12)),
                                  ],
                                ],
                              ),
                            ),
                            if (!isSystem) ...[
                              IconButton(
                                icon: const Icon(Icons.thumb_up,
                                    color: Colors.greenAccent, size: 20),
                                onPressed: () => _adminService.likeMessage(
                                    _selectedRegion, messageId),
                                tooltip: 'Like Message (Golden Glow)',
                              ),
                              IconButton(
                                icon: const Icon(Icons.thumb_down,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () => _adminService.dislikeMessage(
                                    _selectedRegion, messageId),
                                tooltip: 'Hide Message',
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgController,
                decoration: InputDecoration(
                  labelText: _isGhostMode
                      ? 'Chat as $_ghostName (Ghost Mode)...'
                      : 'Send System Message...',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: const Color(0xFF16162F),
                  suffixIcon: _isGhostMode
                      ? IconButton(
                          icon: const Icon(Icons.edit, size: 16),
                          onPressed: () async {
                            final name = await _askForGhostName();
                            if (name != null && name.isNotEmpty) {
                              setState(() => _ghostName = name);
                            }
                          },
                        )
                      : null,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _sendMessage,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                backgroundColor: _isGhostMode
                    ? Colors.orangeAccent
                    : Colors.deepPurpleAccent,
              ),
              child: Text(_isGhostMode ? 'GHOST CHAT' : 'BROADCAST'),
            ),
          ],
        ),
      ],
    );
  }
}
