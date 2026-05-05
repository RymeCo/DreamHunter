import 'package:flutter/material.dart';

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
    _isBannedPermanent = widget.player['isBannedPermanent'] ?? false;
    _isBannedFromChat = widget.player['isBannedFromChat'] ?? false;
    _isBannedFromLeaderboard = widget.player['isBannedFromLeaderboard'] ?? false;
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
      return 'Until ${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('1 Hour'),
                onTap: () => Navigator.pop(context, {
                  'until': DateTime.now()
                      .add(const Duration(hours: 1))
                      .toIso8601String(),
                  'perm': false,
                }),
              ),
              ListTile(
                title: const Text('1 Day'),
                onTap: () => Navigator.pop(context, {
                  'until': DateTime.now()
                      .add(const Duration(days: 1))
                      .toIso8601String(),
                  'perm': false,
                }),
              ),
              ListTile(
                title: const Text('7 Days'),
                onTap: () => Navigator.pop(context, {
                  'until': DateTime.now()
                      .add(const Duration(days: 7))
                      .toIso8601String(),
                  'perm': false,
                }),
              ),
              ListTile(
                title: const Text('Permanent'),
                onTap: () => Navigator.pop(context, {'until': null, 'perm': true}),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: customController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Custom Days',
                          hintText: 'e.g. 30',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () {
                        final days = int.tryParse(customController.text);
                        if (days != null) {
                          Navigator.pop(context, {
                            'until': DateTime.now()
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
              ListTile(
                title: const Text('Lift Restriction',
                    style: TextStyle(color: Colors.green)),
                onTap: () => Navigator.pop(context, {'until': null, 'perm': false}),
              ),
            ],
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
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Manage ${widget.player['name']}'),
          Text(
            widget.player['email'] ?? widget.player['uid'],
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const Divider(),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Account Role'),
              items: const [
                DropdownMenuItem(value: 'player', child: Text('Player')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (v) => setState(() => _role = v!),
            ),
            const SizedBox(height: 24),
            
            // Ban Section
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Account Status', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_formatStatus(_banUntil, _isBannedPermanent)),
              trailing: ElevatedButton(
                onPressed: () => _showDurationPicker('Ban Duration', (until, perm) {
                  setState(() {
                    _banUntil = until;
                    _isBannedPermanent = perm;
                  });
                }),
                child: const Text('Restrict'),
              ),
            ),

            // Mute Section
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Chat Status', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_formatStatus(_muteUntil, _isBannedFromChat)),
              trailing: ElevatedButton(
                onPressed: () => _showDurationPicker('Mute Duration', (until, perm) {
                  setState(() {
                    _muteUntil = until;
                    _isBannedFromChat = perm;
                  });
                }),
                child: const Text('Mute'),
              ),
            ),

            // Leaderboard Section
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Leaderboard Status', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_formatStatus(_leaderboardHideUntil, _isBannedFromLeaderboard)),
              trailing: ElevatedButton(
                onPressed: () => _showDurationPicker('Hide Duration', (until, perm) {
                  setState(() {
                    _leaderboardHideUntil = until;
                    _isBannedFromLeaderboard = perm;
                  });
                }),
                child: const Text('Hide'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onUpdate({
              'level': _level,
              'coins': _coins,
              'stones': _stones,
              'role': _role,
              'isBannedPermanent': _isBannedPermanent,
              'isBannedFromChat': _isBannedFromChat,
              'isBannedFromLeaderboard': _isBannedFromLeaderboard,
              'muteUntil': _muteUntil,
              'banUntil': _banUntil,
              'leaderboardHideUntil': _leaderboardHideUntil,
            });
          },
          child: const Text('Save Changes'),
        ),
      ],
    );
  }

  Widget _buildStatEditor(
    String label,
    int value,
    Function(int) onChanged, {
    int step = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
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
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(4),
              ),
              constraints: const BoxConstraints(minWidth: 60),
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
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
