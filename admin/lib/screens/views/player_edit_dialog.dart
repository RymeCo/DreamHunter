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
  late String _role;

  @override
  void initState() {
    super.initState();
    _coins = widget.player['coins'] ?? 0;
    _stones = widget.player['stones'] ?? 0;
    _level = widget.player['level'] ?? 1;
    _isBannedPermanent = widget.player['isBannedPermanent'] ?? false;
    _isBannedFromChat = widget.player['isBannedFromChat'] ?? false;
    _role = widget.player['role'] ?? 'player';
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
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Permanently Banned'),
              subtitle: const Text('Restrict all access.'),
              value: _isBannedPermanent,
              onChanged: (v) => setState(() => _isBannedPermanent = v),
              activeThumbColor: Colors.red,
            ),
            SwitchListTile(
              title: const Text('Muted from Chat'),
              subtitle: const Text('Restrict chat permissions.'),
              value: _isBannedFromChat,
              onChanged: (v) => setState(() => _isBannedFromChat = v),
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
