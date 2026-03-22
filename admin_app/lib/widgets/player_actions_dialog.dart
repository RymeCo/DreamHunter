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
  final _tweakReasonController = TextEditingController(text: "Admin Tweak");
  
  String _tweakMode = "add"; // "add" or "override"
  bool _forceSync = false;
  bool _isTweaking = false;
  bool _isBanning = false;
  bool _isMuting = false;
  bool _isResettingSpam = false;
  bool _isUpdatingRole = false;
  bool _isWarning = false;

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
    _tweakReasonController.dispose();
    super.dispose();
  }

  void _tweakUser(String uid) async {
    final confirmed = await _showTweakConfirmation();
    if (confirmed != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() => _isTweaking = true);
    
    final success = await _adminService.tweakUser(
      uid: uid,
      level: int.tryParse(_levelController.text.trim()),
      xp: int.tryParse(_xpController.text.trim()),
      dreamCoins: int.tryParse(_dreamController.text.trim()),
      hellStones: int.tryParse(_hellStonesController.text.trim()),
      mode: _tweakMode,
      reason: _tweakReasonController.text.trim(),
    );

    if (mounted) {
      setState(() => _isTweaking = false);
      if (success) {
        if (mounted) {
          showCustomSnackBar(context, 'Tweak applied! Player will receive "Admin Surprise".', type: SnackBarType.success);
        }
        if (widget.onActionComplete != null) {
          widget.onActionComplete!();
        }
      }
    }
  }

  Future<bool?> _showTweakConfirmation() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Confirm Tweak', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mode: ${_tweakMode.toUpperCase()}', style: TextStyle(color: _tweakMode == "add" ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('This will trigger an "Admin Surprise" dialog on the player\'s screen and recalculate their integrity hash.', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('CONFIRM')),
        ],
      ),
    );
  }

  void _toggleBan(String uid, bool isBanned, bool isSuperBanned) async {
    final bool currentIsAdmin = _adminService.isAdmin;

    if (!currentIsAdmin) {
      setState(() => _isBanning = true);
      final success = await _adminService.requestBan(uid, reason: "Moderator Request: ${widget.player['displayName']}");
      if (mounted) {
        setState(() => _isBanning = false);
        if (success) {
          showCustomSnackBar(context, 'Ban Request Sent to Admins', type: SnackBarType.success);
        }
      }
      return;
    }

    setState(() => _isBanning = true);
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
        if (nextSuper) {
          msg = "Player SUPERBANNED (Offline Only)";
        } else if (nextBanned) {
          msg = "Player PERMANENT BANNED";
        }
        
        if (mounted) {
          showCustomSnackBar(context, msg, type: SnackBarType.success);
        }
        if (widget.onActionComplete != null) {
          widget.onActionComplete!();
        }
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
        if (mounted) {
          showCustomSnackBar(context, 'Player muted for ${hours}h', type: SnackBarType.success);
        }
        if (widget.onActionComplete != null) {
          widget.onActionComplete!();
        }
      }
    }
  }

  void _resetSpam(String uid) async {
    setState(() => _isResettingSpam = true);
    final success = await _adminService.resetSpamScore(uid);
    if (mounted) {
      setState(() => _isResettingSpam = false);
      if (success) {
        if (mounted) {
          showCustomSnackBar(context, 'Spam score reset!', type: SnackBarType.success);
        }
        if (widget.onActionComplete != null) {
          widget.onActionComplete!();
        }
      }
    }
  }

  void _warnPlayer(String uid) async {
    final reason = await _showReasonPrompt("Reason for warning");
    if (reason == null || reason.isEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() => _isWarning = true);
    final success = await _adminService.warnUser(uid, reason);
    if (mounted) {
      setState(() => _isWarning = false);
      if (success) {
        if (mounted) {
          showCustomSnackBar(context, 'Warning issued!', type: SnackBarType.success);
        }
        if (widget.onActionComplete != null) {
          widget.onActionComplete!();
        }
        setState(() {
          widget.player['strikeCount'] = (widget.player['strikeCount'] ?? 0) + 1;
        });
      }
    }
  }

  void _toggleModerator(String uid, bool currentStatus) async {
    setState(() => _isUpdatingRole = true);
    final success = await _adminService.updateModeratorStatus(uid, !currentStatus);
    if (mounted) {
      setState(() => _isUpdatingRole = false);
      if (success) {
        if (mounted) {
          showCustomSnackBar(context, !currentStatus ? 'Moderator Role Granted' : 'Moderator Role Revoked', type: SnackBarType.success);
        }
        if (widget.onActionComplete != null) {
          widget.onActionComplete!();
        }
        setState(() => widget.player['isModerator'] = !currentStatus);
      }
    }
  }

  void _customMute(String uid) async {
    final dt = await _pickCustomDateTime();
    if (dt == null) {
      return;
    }
    
    if (!mounted) {
      return;
    }

    final bool currentIsAdmin = _adminService.isAdmin;
    if (!currentIsAdmin) {
      final diff = dt.difference(DateTime.now());
      if (diff.inHours > 24) {
        showCustomSnackBar(context, 'Moderators can only mute up to 24h. Adjusting...', type: SnackBarType.info);
        _quickMute(uid, 24);
        return;
      }
    }

    setState(() => _isMuting = true);
    final success = await _adminService.muteUser(uid, null, until: dt.toUtc().toIso8601String());
    if (mounted) {
      setState(() => _isMuting = false);
      if (success) {
        showCustomSnackBar(context, 'Custom mute applied until ${dt.toString().split('.')[0]}', type: SnackBarType.success);
        if (widget.onActionComplete != null) widget.onActionComplete!();
      }
    }
  }

  Future<DateTime?> _pickCustomDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) {
      return null;
    }
    
    if (!mounted) {
      return null;
    }
    
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<String?> _showReasonPrompt(String title) async {
    String reason = "";
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "Enter reason...", hintStyle: TextStyle(color: Colors.white38)),
          onChanged: (value) => reason = value,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, reason), child: const Text('SUBMIT')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.player['uid'] ?? '';
    final displayName = widget.player['displayName'] ?? 'Unknown Player';
    final isBanned = widget.player['isBanned'] ?? false;
    final isSuperBanned = widget.player['isSuperBanned'] ?? false;
    final isModerator = widget.player['isModerator'] ?? false;
    final spamScore = widget.player['spamScore'] ?? 0;
    final isFlagged = widget.player['isFlagged'] ?? false;
    final strikeCount = widget.player['strikeCount'] ?? 0;
    
    final bool currentIsAdmin = _adminService.isAdmin;

    String banLabel = currentIsAdmin ? "PERMANENT BAN" : "REQUEST BAN";
    Color banColor = Colors.redAccent;
    IconData banIcon = Icons.gavel;
    
    if (isSuperBanned) {
      banLabel = "UNBAN PLAYER";
      banColor = Colors.greenAccent;
      banIcon = Icons.restore;
    } else if (isBanned) {
      banLabel = currentIsAdmin ? "UPGRADE TO SUPERBAN" : "REQUEST BAN";
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
                        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                        child: const Text('SUPERBANNED', style: TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.bold)),
                      )
                      ] else if (isBanned) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                        child: const Text('BANNED', style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold)),
                      )

                    ]
                  ],
                ),
                subtitle: Text('UID: $uid', style: const TextStyle(fontSize: 10, color: Colors.white38)),
              ),

              const SizedBox(height: 16),

              // Save Tweak (Additive vs Override)
              const Text('SAVE TWEAK (Admin Surprise)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.cyanAccent, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              
              // Mode Selector
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _tweakMode = "add"),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _tweakMode == "add" ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _tweakMode == "add" ? Colors.greenAccent : Colors.white10),
                        ),
                        child: Center(child: Text('ADDITIVE', style: TextStyle(color: _tweakMode == "add" ? Colors.greenAccent : Colors.white38, fontWeight: FontWeight.bold, fontSize: 10))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _tweakMode = "override"),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _tweakMode == "override" ? Colors.redAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _tweakMode == "override" ? Colors.redAccent : Colors.white10),
                        ),
                        child: Center(child: Text('FORCE OVERRIDE', style: TextStyle(color: _tweakMode == "override" ? Colors.redAccent : Colors.white38, fontWeight: FontWeight.bold, fontSize: 10))),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: AdminTextField(label: 'Dream Coins', controller: _dreamController, prefixIcon: Icons.cloud_circle)),
                  const SizedBox(width: 12),
                  Expanded(child: AdminTextField(label: 'Hell Stones', controller: _hellStonesController, prefixIcon: Icons.local_fire_department)),
                ],
              ),
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
                children: [
                  Expanded(child: AdminTextField(label: 'Reason', controller: _tweakReasonController, prefixIcon: Icons.edit_note)),
                  const SizedBox(width: 12),
                  AdminButton(
                    onPressed: _isTweaking ? null : () => _tweakUser(uid), 
                    label: 'TWEAK', 
                    isLoading: _isTweaking,
                    color: Colors.cyanAccent
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
                  if (currentIsAdmin)
                    AdminButton(
                      onPressed: _isUpdatingRole ? null : () => _toggleModerator(uid, isModerator), 
                      label: isModerator ? 'REVOKE MOD' : 'GRANT MOD', 
                      icon: isModerator ? Icons.remove_moderator : Icons.verified_user, 
                      isLoading: _isUpdatingRole,
                      color: isModerator ? Colors.orange : Colors.greenAccent
                    ),
                  AdminButton(
                    onPressed: _isResettingSpam ? null : () => _resetSpam(uid), 
                    label: 'RESET SPAM ($spamScore)', 
                    icon: Icons.refresh, 
                    isLoading: _isResettingSpam,
                    color: Colors.cyanAccent
                  ),
                  AdminButton(
                    onPressed: _isWarning ? null : () => _warnPlayer(uid), 
                    label: 'WARN PLAYER ($strikeCount/3)', 
                    icon: Icons.warning_amber_rounded, 
                    isLoading: _isWarning,
                    color: Colors.orangeAccent
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
                  if (currentIsAdmin) _muteBadgeAction(uid, '7D', 168),
                  _customMuteBadgeAction(uid),
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

  Widget _customMuteBadgeAction(String uid) {
    return InkWell(
      onTap: _isMuting ? null : () => _customMute(uid),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        child: const Text('CUSTOM', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _muteBadgeAction(String uid, String label, int hours) {
    return InkWell(
      onTap: _isMuting ? null : () => _quickMute(uid, hours),
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
