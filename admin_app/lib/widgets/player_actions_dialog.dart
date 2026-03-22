import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import 'custom_snackbar.dart';
import 'liquid_glass_panel.dart';
import 'admin_ui_components.dart';

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
  final TextEditingController _levelController = TextEditingController();
  final TextEditingController _xpController = TextEditingController();
  final TextEditingController _warnReasonController = TextEditingController();
  bool _forceSync = false;

  @override
  void initState() {
    super.initState();
    _levelController.text = (widget.player['level'] ?? 1).toString();
    _xpController.text = (widget.player['xp'] ?? 0).toString();
    _forceSync = widget.player['forceSyncNext'] ?? false;
  }

  @override
  void dispose() {
    _levelController.dispose();
    _xpController.dispose();
    _warnReasonController.dispose();
    super.dispose();
  }

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

  void _updateSave(String uid) async {
    final level = int.tryParse(_levelController.text.trim());
    final xp = int.tryParse(_xpController.text.trim());

    final success = await _adminService.updatePlayerSave(
      uid,
      level: level,
      xp: xp,
      forceSyncNext: _forceSync,
    );

    if (success && mounted) {
      showCustomSnackBar(context, 'Player save state updated!', type: SnackBarType.success);
      if (widget.onActionComplete != null) widget.onActionComplete!();
      Navigator.pop(context);
    }
  }

  void _quickBan(String uid, bool isPermanent) async {
    final dt = isPermanent ? null : await _pickCustomDateTime();
    if (!isPermanent && dt == null) return;

    final success = await _adminService.banUser(
      uid,
      true,
      until: dt?.toUtc().toIso8601String(),
    );

    if (success && mounted) {
      showCustomSnackBar(context, isPermanent ? 'Player Perm-Banned' : 'Player Temp-Banned', type: SnackBarType.success);
      if (widget.onActionComplete != null) widget.onActionComplete!();
      Navigator.pop(context);
    }
  }

  void _quickMute(String uid, int hours) async {
    final success = await _adminService.muteUser(uid, hours);
    if (success && mounted) {
      showCustomSnackBar(context, 'Player muted for ${hours}h', type: SnackBarType.success);
      if (widget.onActionComplete != null) widget.onActionComplete!();
      Navigator.pop(context);
    }
  }

  void _resetSpam(String uid) async {
    final success = await _adminService.resetSpamScore(uid);
    if (success && mounted) {
      showCustomSnackBar(context, 'Spam score reset!', type: SnackBarType.success);
      if (widget.onActionComplete != null) widget.onActionComplete!();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.player['uid'] ?? '';
    final displayName = widget.player['displayName'] ?? 'Unknown Player';
    final dreamCoins = widget.player['dreamCoins'] ?? 0;
    final hellStones = widget.player['hellStones'] ?? 0;
    final spamScore = widget.player['spamScore'] ?? 0;
    final isFlagged = widget.player['isFlagged'] ?? false;

    return Center(
      child: LiquidGlassPanel(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Service Hub: Player Control',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.amberAccent),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white38)),
                ],
              ),
              const Divider(color: Colors.white10),

              // Player Identity & Locked Economy
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?'),
                ),
                title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text('UID: $uid', style: const TextStyle(fontSize: 10, color: Colors.white38)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _economyBadge(Icons.cloud_circle, '$dreamCoins', Colors.cyanAccent),
                    const SizedBox(width: 8),
                    _economyBadge(Icons.local_fire_department, '$hellStones', Colors.orangeAccent),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Save State Editor
              const Text('SAVE STATE EDITOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blueAccent, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: AdminTextField(label: 'Level', controller: _levelController, prefixIcon: Icons.trending_up)),
                  const SizedBox(width: 12),
                  Expanded(child: AdminTextField(label: 'XP', controller: _xpController, prefixIcon: Icons.bolt)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Force Sync on next login', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Switch(
                    value: _forceSync,
                    onChanged: (v) => setState(() => _forceSync = v),
                    activeThumbColor: Colors.amberAccent,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AdminButton(onPressed: () => _updateSave(uid), label: 'APPLY SAVE TWEAKS', icon: Icons.save_rounded, color: Colors.blueAccent),

              const Divider(height: 40, color: Colors.white10),

              // Access Control
              const Text('ACCESS CONTROL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.redAccent, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AdminButton(onPressed: () => _quickBan(uid, true), label: 'PERM BAN', icon: Icons.gavel, color: Colors.redAccent),
                  AdminButton(onPressed: () => _quickBan(uid, false), label: 'TEMP BAN', icon: Icons.timer, color: Colors.orange),
                  AdminButton(onPressed: () => _resetSpam(uid), label: 'RESET SPAM ($spamScore)', icon: Icons.refresh, color: Colors.cyanAccent),
                ],
              ),

              const SizedBox(height: 20),

              // Quick Mutes
              const Text('CHAT RESTRICTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.orangeAccent, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _muteBadgeAction(uid, '1H', 1),
                  _muteBadgeAction(uid, '24H', 24),
                  _muteBadgeAction(uid, '7D', 168),
                  if (isFlagged)
                    AdminButton(onPressed: () => _resetSpam(uid), label: 'UNFLAG USER', icon: Icons.security_outlined, color: Colors.greenAccent),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _economyBadge(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _muteBadgeAction(String uid, String label, int hours) {
    return InkWell(
      onTap: () => _quickMute(uid, hours),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(label, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }
}
