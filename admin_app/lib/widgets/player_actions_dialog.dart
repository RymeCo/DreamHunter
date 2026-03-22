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
  final _levelController = TextEditingController();
  final _xpController = TextEditingController();
  final _dreamController = TextEditingController();
  final _hellStonesController = TextEditingController();
  final _warnReasonController = TextEditingController();
  
  bool _forceSync = false;
  bool _isUpdatingSave = false;
  bool _isUpdatingCurrency = false;
  bool _isBanning = false;
  bool _isMuting = false;
  bool _isResettingSpam = false;

  @override
  void initState() {
    super.initState();
    _levelController.text = (widget.player['level'] ?? 1).toString();
    _xpController.text = (widget.player['xp'] ?? 0).toString();
    _dreamController.text = (widget.player['dreamCoins'] ?? 0).toString();
    _hellStonesController.text = (widget.player['hellStones'] ?? 0).toString();
    _forceSync = widget.player['forceSyncNext'] ?? false;
  }

  @override
  void dispose() {
    _levelController.dispose();
    _xpController.dispose();
    _dreamController.dispose();
    _hellStonesController.dispose();
    _warnReasonController.dispose();
    super.dispose();
  }

  void _updateSave(String uid) async {
    setState(() => _isUpdatingSave = true);
    final level = int.tryParse(_levelController.text.trim());
    final xp = int.tryParse(_xpController.text.trim());

    final success = await _adminService.updatePlayerSave(
      uid,
      level: level,
      xp: xp,
      forceSyncNext: _forceSync,
    );

    if (mounted) {
      setState(() => _isUpdatingSave = false);
      if (success) {
        showCustomSnackBar(context, 'Player save updated!', type: SnackBarType.success);
        if (widget.onActionComplete != null) widget.onActionComplete!();
      }
    }
  }

  void _updateCurrency(String uid) async {
    setState(() => _isUpdatingCurrency = true);
    final dream = int.tryParse(_dreamController.text.trim());
    final hell = int.tryParse(_hellStonesController.text.trim());

    final success = await _adminService.updatePlayerCurrency(
      uid,
      dreamCoins: dream,
      hellStones: hell,
    );

    if (mounted) {
      setState(() => _isUpdatingCurrency = false);
      if (success) {
        showCustomSnackBar(context, 'Currency adjusted & Hash Recalculated!', type: SnackBarType.success);
        if (widget.onActionComplete != null) widget.onActionComplete!();
      }
    }
  }

  void _toggleBan(String uid, bool isBanned, bool isSuperBanned) async {
    setState(() => _isBanning = true);
    // Logic: Unban -> Ban -> Superban -> Unban
    bool nextBanned = false;
    bool nextSuper = false;

    if (!isBanned && !isSuperBanned) {
      nextBanned = true;
      nextSuper = false;
    } else if (isBanned && !isSuperBanned) {
      nextBanned = true;
      nextSuper = true;
    } else {
      nextBanned = false;
      nextSuper = false;
    }

    final success = await _adminService.banUser(uid, nextBanned, isSuperBanned: nextSuper);

    if (mounted) {
      setState(() => _isBanning = false);
      if (success) {
        String msg = "Player Unbanned";
        if (nextSuper) msg = "Player SUPERBANNED (Offline Only)";
        else if (nextBanned) msg = "Player PERMANENT BANNED";
        
        showCustomSnackBar(context, msg, type: SnackBarType.success);
        if (widget.onActionComplete != null) widget.onActionComplete!();
        setState(() {
          widget.player['isBanned'] = nextBanned;
          widget.player['isSuperBanned'] = nextSuper;
        });
      }
    }
  }

  void _quickMute(String uid, int hours) async {
    setState(() => _isMuting = true);
    final success = await _adminService.muteUser(uid, hours);
    if (mounted) {
      setState(() => _isMuting = false);
      if (success) {
        showCustomSnackBar(context, 'Player muted for ${hours}h', type: SnackBarType.success);
        if (widget.onActionComplete != null) widget.onActionComplete!();
      }
    }
  }

  void _resetSpam(String uid) async {
    setState(() => _isResettingSpam = true);
    final success = await _adminService.resetSpamScore(uid);
    if (mounted) {
      setState(() => _isResettingSpam = false);
      if (success) {
        showCustomSnackBar(context, 'Spam score reset!', type: SnackBarType.success);
        if (widget.onActionComplete != null) widget.onActionComplete!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.player['uid'] ?? '';
    final displayName = widget.player['displayName'] ?? 'Unknown Player';
    final isBanned = widget.player['isBanned'] ?? false;
    final isSuperBanned = widget.player['isSuperBanned'] ?? false;
    final spamScore = widget.player['spamScore'] ?? 0;
    final isFlagged = widget.player['isFlagged'] ?? false;

    String banLabel = "PERMANENT BAN";
    Color banColor = Colors.redAccent;
    IconData banIcon = Icons.gavel;
    if (isSuperBanned) {
      banLabel = "UNBAN PLAYER";
      banColor = Colors.greenAccent;
      banIcon = Icons.restore;
    } else if (isBanned) {
      banLabel = "UPGRADE TO SUPERBAN";
      banColor = Colors.deepOrangeAccent;
      banIcon = Icons.security;
    }

    return Center(
      child: LiquidGlassPanel(
        width: 550,
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

              // Player Identity
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isSuperBanned ? Colors.orange : (isBanned ? Colors.red : Colors.deepPurple),
                  child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?'),
                ),
                title: Row(
                  children: [
                    Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    if (isSuperBanned) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                        child: const Text('SUPERBANNED', style: TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.bold)),
                      )
                    ] else if (isBanned) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                        child: const Text('BANNED', style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold)),
                      )
                    ]
                  ],
                ),
                subtitle: Text('UID: $uid', style: const TextStyle(fontSize: 10, color: Colors.white38)),
              ),

              const SizedBox(height: 16),

              // Economy Injection
              const Text('ECONOMY INJECTION (Safe Edit)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.cyanAccent, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: AdminTextField(label: 'Dream Coins', controller: _dreamController, prefixIcon: Icons.cloud_circle)),
                  const SizedBox(width: 12),
                  Expanded(child: AdminTextField(label: 'Hell Stones', controller: _hellStonesController, prefixIcon: Icons.local_fire_department)),
                  const SizedBox(width: 12),
                  AdminButton(
                    onPressed: _isUpdatingCurrency ? null : () => _updateCurrency(uid), 
                    label: 'INJECT', 
                    isLoading: _isUpdatingCurrency,
                    color: Colors.cyanAccent
                  ),
                ],
              ),

              const Divider(height: 40, color: Colors.white10),

              // Save State Editor
              const Text('SAVE STATE EDITOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blueAccent, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: AdminTextField(label: 'Level', controller: _levelController, prefixIcon: Icons.trending_up)),
                  const SizedBox(width: 12),
                  Expanded(child: AdminTextField(label: 'XP', controller: _xpController, prefixIcon: Icons.bolt)),
                  const SizedBox(width: 12),
                  AdminButton(
                    onPressed: _isUpdatingSave ? null : () => _updateSave(uid), 
                    label: 'SAVE', 
                    isLoading: _isUpdatingSave,
                    color: Colors.blueAccent
                  ),
                ],
              ),
              const SizedBox(height: 8),
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

              const Divider(height: 40, color: Colors.white10),

              // Access Control
              const Text('ACCESS CONTROL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.redAccent, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AdminButton(
                    onPressed: _isBanning ? null : () => _toggleBan(uid, isBanned, isSuperBanned), 
                    label: banLabel, 
                    icon: banIcon, 
                    isLoading: _isBanning,
                    color: banColor
                  ),
                  AdminButton(
                    onPressed: _isResettingSpam ? null : () => _resetSpam(uid), 
                    label: 'RESET SPAM ($spamScore)', 
                    icon: Icons.refresh, 
                    isLoading: _isResettingSpam,
                    color: Colors.cyanAccent
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Chat Restrictions
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
