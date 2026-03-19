import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/admin_provider.dart';
import '../services/admin_service.dart';
import 'custom_snackbar.dart';
import 'liquid_glass_dialog.dart';

class PlayerActionsDialog extends StatefulWidget {
  final Map<String, dynamic> player;
  final VoidCallback? onActionComplete;

  const PlayerActionsDialog({
    super.key,
    required this.player,
    this.onActionComplete,
  });

  @override
  State<PlayerActionsDialog> createState() => _PlayerActionsDialogState();
}

class _PlayerActionsDialogState extends State<PlayerActionsDialog> {
  final AdminService _adminService = AdminService();
  final TextEditingController _warnReasonController = TextEditingController();

  Future<DateTime?> _pickCustomDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _toggleBan(String uid, bool currentStatus, {String? until}) async {
    final success =
        await _adminService.banUser(uid, !currentStatus, until: until);
    if (!mounted) return;

    if (success) {
      showCustomSnackBar(
        context,
        currentStatus
            ? 'User unbanned!'
            : (until != null ? 'Temp ban applied!' : 'User banned!'),
        type: SnackBarType.success,
      );
      if (widget.onActionComplete != null) widget.onActionComplete!();
      Navigator.pop(context, currentStatus ? 'unban' : 'ban');
    }
  }

  void _muteUser(String uid, int? hours, {String? until}) async {
    final success = await _adminService.muteUser(uid, hours, until: until);
    if (!mounted) return;

    if (success) {
      showCustomSnackBar(
        context,
        hours == 0 ? 'User unmuted!' : 'Mute applied!',
        type: SnackBarType.success,
      );
      if (widget.onActionComplete != null) widget.onActionComplete!();
      Navigator.pop(context, hours == 0 ? 'unmute' : 'mute');
    }
  }

  void _warnUser(String uid) async {
    final reason = _warnReasonController.text.trim();
    if (reason.isEmpty) {
      showCustomSnackBar(context, 'Please provide a reason for the warning.',
          type: SnackBarType.info);
      return;
    }

    final success = await _adminService.warnUser(uid, reason);
    if (!mounted) return;

    if (success) {
      showCustomSnackBar(context, 'Warning issued to player!',
          type: SnackBarType.success);
      if (widget.onActionComplete != null) widget.onActionComplete!();
      Navigator.pop(context, 'warn');
    }
  }

  void _toggleModerator(String uid, bool currentStatus) async {
    final success =
        await _adminService.updateModeratorStatus(uid, !currentStatus);
    if (!mounted) return;

    if (success) {
      showCustomSnackBar(
        context,
        currentStatus
            ? 'Moderator powers revoked.'
            : 'Moderator powers granted!',
        type: SnackBarType.success,
      );
      if (widget.onActionComplete != null) widget.onActionComplete!();
      Navigator.pop(context, 'moderator');
    }
  }

  @override
  void dispose() {
    _warnReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AdminProvider>(context);
    final isModOnly = provider.isModerator && !provider.isAdmin;

    return StreamBuilder<DocumentSnapshot>(
      stream: _adminService.getAutoModConfigStream(),
      builder: (context, snapshot) {
        final modConfig = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final canMute = !isModOnly || (modConfig['modCanMute'] ?? true);
        final canWarn = !isModOnly || (modConfig['modCanWarn'] ?? true);

        final uid = widget.player['uid'] ?? '';
        final displayName = widget.player['displayName'] ?? 'Unknown Player';
        final isBanned = widget.player['isBanned'] ?? false;
        final isMuted = widget.player['mutedUntil'] != null;
        final isModerator = widget.player['isModerator'] ?? false;
        final warnings = widget.player['warnings'] as List? ?? [];

        return Center(
          child: LiquidGlassDialog(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Moderate Player',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: Text(displayName[0].toUpperCase()),
                    ),
                    title: Text(
                      displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('UID: $uid'),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy,
                          size: 18, color: Colors.blueAccent),
                      onPressed: () =>
                          copyToClipboardWithFeedback(context, uid, 'User ID'),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // TIERED POWER SECTION (ADMIN ONLY)
                  if (provider.isAdmin) ...[
                    const Text(
                      'Roles & Privileges',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Moderator Powers'),
                      subtitle: const Text(
                          'Allow this player to mute and warn others.'),
                      value: isModerator,
                      onChanged: (val) => _toggleModerator(uid, isModerator),
                      activeThumbColor: Colors.blueAccent,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(height: 40, color: Colors.white10),
                  ],

                  if (provider.isAdmin) ...[
                    const Text(
                      'Access Control',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                    const SizedBox(height: 12),
                    if (isBanned)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _toggleBan(uid, true),
                          icon: const Icon(Icons.restore),
                          label: const Text('UNBAN PLAYER'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _toggleBan(uid, false),
                              icon: const Icon(Icons.block),
                              label: const Text('PERMANENT BAN'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final dt = await _pickCustomDateTime();
                                if (dt != null) {
                                  _toggleBan(uid, false,
                                      until: dt.toUtc().toIso8601String());
                                }
                              },
                              icon: const Icon(Icons.timer),
                              label: const Text('TEMP BAN'),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                  ],

                  // WARNING SYSTEM
                  if (canWarn) ...[
                    const Text(
                      'Warning System (Strikes)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.yellowAccent),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _warnReasonController,
                            decoration: const InputDecoration(
                              hintText: 'Reason for warning...',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _warnUser(uid),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange),
                          child: const Text('WARN'),
                        ),
                      ],
                    ),
                    if (warnings.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Active Strikes: ${warnings.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      ...warnings.map((w) => Text(
                          '• ${w['reason'] ?? 'No reason'}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70))),
                    ],
                    const Divider(height: 40, color: Colors.white10),
                  ],

                  // CHAT RESTRICTIONS
                  if (canMute) ...[
                    const Text(
                      'Chat Restrictions',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orangeAccent),
                    ),
                    const SizedBox(height: 12),
                    if (isMuted) ...[
                      Text(
                          'Currently muted until: ${widget.player['mutedUntil']}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _muteUser(uid, 0),
                          icon: const Icon(Icons.volume_up),
                          label: const Text('UNMUTE NOW'),
                        ),
                      ),
                    ] else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _muteBtn(uid, '24h', 24),
                          _muteBtn(uid, '3d', 24 * 3),
                          _muteBtn(uid, '1w', 24 * 7),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final dt = await _pickCustomDateTime();
                              if (dt != null) {
                                _muteUser(uid, null,
                                    until: dt.toUtc().toIso8601String());
                              }
                            },
                            icon: const Icon(Icons.edit_calendar),
                            label: const Text('Custom...'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white12),
                          ),
                        ],
                      ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _muteBtn(String uid, String label, int hours) {
    return ElevatedButton(
      onPressed: () => _muteUser(uid, hours),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
      child: Text(label),
    );
  }
}
