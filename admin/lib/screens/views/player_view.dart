import 'dart:convert';
import 'package:flutter/material.dart';
import '../../api_gateway.dart';

class PlayerView extends StatefulWidget {
  const PlayerView({super.key});

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  final ApiGateway _api = ApiGateway();
  final TextEditingController _searchController = TextEditingController();
  
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.length < 2) return;

    setState(() => _isSearching = true);
    try {
      final response = await _api.get('/admin/players/search?q=$query');
      if (context.mounted && response.statusCode == 200) {
        setState(() {
          _searchResults = json.decode(response.body);
          _isSearching = false;
        });
      }
    } catch (e) {
      if (context.mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  Future<void> _showPlayerDetails(String uid) async {
    // 1. Fetch Real-time data (Just-in-time)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await _api.get('/admin/players/$uid');
      
      if (!context.mounted) return;
      // Use Navigator.of(context) which is explicitly allowed if context.mounted is checked
      Navigator.of(context).pop(); // Close loading

      if (response.statusCode == 200) {
        final player = json.decode(response.body);
        _showEditDialog(player);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch player details: $e')),
        );
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> player) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _PlayerEditDialog(
          player: player,
          onUpdate: (updatedData) async {
            if (!dialogContext.mounted) return;
            
            // Final Confirmation
            final confirm = await showDialog<bool>(
              context: dialogContext,
              builder: (context) => AlertDialog(
                title: const Text('Confirm Changes'),
                content: const Text(
                    'Are you sure you want to apply these changes? This action is irreversible.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Apply',
                          style: TextStyle(color: Colors.red))),
                ],
              ),
            );

            if (confirm == true) {
              try {
                final response = await _api.patch(
                    '/admin/players/${player['uid']}',
                    body: updatedData);
                
                if (!dialogContext.mounted) return;

                if (response.statusCode == 200) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                          content: Text('Player updated successfully!')));
                  Navigator.of(dialogContext).pop();
                  _search(); // Refresh results to show new stats/role
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Update failed: $e')));
                }
              }
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Player Management',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          const Text('Search for players by Name or UID to manage their accounts.'),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Enter Nickname or UID...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _isSearching ? null : _search,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSearching ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Search'),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text('No players found. Try a different search.'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final p = _searchResults[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: p['role'] == 'admin' ? Colors.deepPurple : Colors.blue.shade100,
                            child: Icon(p['role'] == 'admin' ? Icons.admin_panel_settings : Icons.person, color: p['role'] == 'admin' ? Colors.white : Colors.blue),
                          ),
                          title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('LVL ${p['level']} • ${p['email'] ?? "No Email"}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showPlayerDetails(p['uid']),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlayerEditDialog extends StatefulWidget {
  final Map<String, dynamic> player;
  final Function(Map<String, dynamic>) onUpdate;

  const _PlayerEditDialog({required this.player, required this.onUpdate});

  @override
  State<_PlayerEditDialog> createState() => _PlayerEditDialogState();
}

class _PlayerEditDialogState extends State<_PlayerEditDialog> {
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatEditor('Level', _level, (v) => setState(() => _level = v)),
            _buildStatEditor('Coins', _coins, (v) => setState(() => _coins = v), step: 100),
            _buildStatEditor('Stones', _stones, (v) => setState(() => _stones = v), step: 10),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
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

  Widget _buildStatEditor(String label, int value, Function(int) onChanged, {int step = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          IconButton(onPressed: () => onChanged(value - step), icon: const Icon(Icons.remove_circle_outline)),
          SizedBox(width: 60, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16))),
          IconButton(onPressed: () => onChanged(value + step), icon: const Icon(Icons.add_circle_outline)),
        ],
      ),
    );
  }
}
