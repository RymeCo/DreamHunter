import 'package:flutter/material.dart';
import '../../utils/formatters.dart';

class PlayerEditDialog extends StatefulWidget {
  final Map<String, dynamic> player;
  final Function(Map<String, dynamic>) onUpdate;

  const PlayerEditDialog({
    super.key,
    required this.player,
    required this.onUpdate,
  });

  @override
  State<PlayerEditDialog> createState() => _PlayerEditDialogState();
}

class _PlayerEditDialogState extends State<PlayerEditDialog> {
  late int _coins;
  late int _stones;
  late int _level;
  late bool _isVerified;
  late bool _isBannedPermanent;
  late bool _isBannedFromChat;
  late bool _isBannedFromLeaderboard;
  late String? _muteUntil;
  late String? _banUntil;
  late String? _leaderboardHideUntil;
  late String _role;

  @override
  void initState() {
    super.initState();
    _coins = widget.player['coins'] ?? 0;
    _stones = widget.player['stones'] ?? 0;
    _level = widget.player['level'] ?? 1;
    _isVerified = widget.player['isVerified'] ?? false;
    _isBannedPermanent = widget.player['isBannedPermanent'] ?? false;
    _isBannedFromChat = widget.player['isBannedFromChat'] ?? false;
    _isBannedFromLeaderboard =
        widget.player['isBannedFromLeaderboard'] ?? false;
    _muteUntil = widget.player['muteUntil'];
    _banUntil = widget.player['banUntil'];
    _leaderboardHideUntil = widget.player['leaderboardHideUntil'];
    _role = widget.player['role'] ?? 'player';
  }

  String _formatStatus(String? until, bool isPermanent) {
    if (isPermanent) return 'Permanent';
    if (until == null) return 'Active';
    try {
      final date = DateTime.parse(until);
      if (date.isBefore(DateTime.now())) return 'Active (Expired)';
      return 'Until ${AppFormatters.formatFullDateTime(date)}';
    } catch (_) {
      return 'Restricted';
    }
  }

  Future<void> _showDurationPicker(
    String title,
    Function(String?, bool) onSelected,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        final customController = TextEditingController();
        return AlertDialog(
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('1 Hour'),
                  onTap: () => Navigator.pop(context, {
                    'until': DateTime.now()
                        .toUtc()
                        .add(const Duration(hours: 1))
                        .toIso8601String(),
                    'perm': false,
                  }),
                ),
                ListTile(
                  title: const Text('1 Day'),
                  onTap: () => Navigator.pop(context, {
                    'until': DateTime.now()
                        .toUtc()
                        .add(const Duration(days: 1))
                        .toIso8601String(),
                    'perm': false,
                  }),
                ),
                ListTile(
                  title: const Text('7 Days'),
                  onTap: () => Navigator.pop(context, {
                    'until': DateTime.now()
                        .toUtc()
                        .add(const Duration(days: 7))
                        .toIso8601String(),
                    'perm': false,
                  }),
                ),
                ListTile(
                  title: const Text('Permanent'),
                  onTap: () =>
                      Navigator.pop(context, {'until': null, 'perm': true}),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Custom Days',
                            hintText: 'e.g. 30',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.check, size: 20),
                        onPressed: () {
                          final days = int.tryParse(customController.text);
                          if (days != null) {
                            Navigator.pop(context, {
                              'until': DateTime.now()
                                  .toUtc()
                                  .add(Duration(days: days))
                                  .toIso8601String(),
                              'perm': false,
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  title: const Text(
                    'Lift Restriction',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  onTap: () =>
                      Navigator.pop(context, {'until': null, 'perm': false}),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null) {
      onSelected(result['until'], result['perm']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Manage ${widget.player['name']}',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              size: 20,
                              color: Colors.blue,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        widget.player['email'] ?? widget.player['uid'],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSectionTitle('Statistics'),
                    _buildStatEditor(
                      'Level',
                      _level,
                      (v) => setState(() => _level = v),
                    ),
                    _buildStatEditor(
                      'Coins',
                      _coins,
                      (v) => setState(() => _coins = v),
                      step: 100,
                    ),
                    _buildStatEditor(
                      'Stones',
                      _stones,
                      (v) => setState(() => _stones = v),
                      step: 10,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Permissions'),
                    SwitchListTile(
                      title: const Text('Email Verified'),
                      subtitle: const Text(
                        'Manually toggle verification status',
                      ),
                      value: _isVerified,
                      onChanged: (v) => setState(() => _isVerified = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _role,
                      decoration: InputDecoration(
                        labelText: 'Account Role',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'player',
                          child: Text('Player'),
                        ),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (v) => setState(() => _role = v!),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Restrictions'),
                    _buildRestrictionTile(
                      'Account Status',
                      _formatStatus(_banUntil, _isBannedPermanent),
                      Icons.gavel,
                      () => _showDurationPicker('Ban Duration', (until, perm) {
                        setState(() {
                          _banUntil = until;
                          _isBannedPermanent = perm;
                        });
                      }),
                    ),
                    _buildRestrictionTile(
                      'Chat Status',
                      _formatStatus(_muteUntil, _isBannedFromChat),
                      Icons.speaker_notes_off,
                      () => _showDurationPicker('Mute Duration', (until, perm) {
                        setState(() {
                          _muteUntil = until;
                          _isBannedFromChat = perm;
                        });
                      }),
                    ),
                    _buildRestrictionTile(
                      'Leaderboard',
                      _formatStatus(
                        _leaderboardHideUntil,
                        _isBannedFromLeaderboard,
                      ),
                      Icons.visibility_off,
                      () => _showDurationPicker('Hide Duration', (until, perm) {
                        setState(() {
                          _leaderboardHideUntil = until;
                          _isBannedFromLeaderboard = perm;
                        });
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    widget.onUpdate({
                      'level': _level,
                      'coins': _coins,
                      'stones': _stones,
                      'role': _role,
                      'isVerified': _isVerified,
                      'isBannedPermanent': _isBannedPermanent,
                      'isBannedFromChat': _isBannedFromChat,
                      'isBannedFromLeaderboard': _isBannedFromLeaderboard,
                      'muteUntil': _muteUntil,
                      'banUntil': _banUntil,
                      'leaderboardHideUntil': _leaderboardHideUntil,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onPrimaryContainer,
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildRestrictionTile(
    String title,
    String status,
    IconData icon,
    VoidCallback onEdit,
  ) {
    final isActive = status.contains('Active') || status == 'N/A';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? Theme.of(context).colorScheme.outlineVariant
                  : Colors.red.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isActive ? null : Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive
                            ? Theme.of(context).colorScheme.outline
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatEditor(
    String label,
    int value,
    Function(int) onChanged, {
    int step = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            onPressed: () => onChanged(value - step),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          InkWell(
            onTap: () async {
              final controller = TextEditingController(text: value.toString());
              final newValue = await showDialog<int>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Edit $label'),
                  content: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Enter new value',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        final val = int.tryParse(controller.text);
                        Navigator.pop(context, val);
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
              if (newValue != null) {
                onChanged(newValue);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              constraints: const BoxConstraints(minWidth: 80),
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => onChanged(value + step),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
