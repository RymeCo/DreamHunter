import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/liquid_glass_dialog.dart';
import '../widgets/player_actions_dialog.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _players = [];
  bool _isLoading = false;

  bool? _filterBanned;
  bool? _filterAdmin;

  final Set<String> _selectedUids = {};

  @override
  void initState() {
    super.initState();
    _fetchPlayers();
  }

  Future<void> _fetchPlayers() async {
    setState(() {
      _isLoading = true;
      _selectedUids.clear();
    });
    try {
      final results = await _adminService.searchPlayers(
        query: _searchController.text.trim(),
        isBanned: _filterBanned,
        isAdmin: _filterAdmin,
      );
      if (!mounted) return;
      setState(() {
        _players = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showCustomSnackBar(
        context,
        'Error: ${e.toString().replaceAll('Exception: ', '')}',
        type: SnackBarType.error,
      );
    }
  }

  void _showPlayerActions(Map<String, dynamic> player) {
    if (_selectedUids.isNotEmpty) {
      _toggleSelection(player['uid']);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => PlayerActionsDialog(
        player: player,
        onActionComplete: _fetchPlayers,
      ),
    );
  }

  void _toggleSelection(String? uid) {
    if (uid == null) return;
    setState(() {
      if (_selectedUids.contains(uid)) {
        _selectedUids.remove(uid);
      } else {
        _selectedUids.add(uid);
      }
    });
  }

  Future<void> _performBatchAction(String action, {Map<String, dynamic>? params}) async {
    if (_selectedUids.isEmpty) return;
    
    final success = await _adminService.performBatchAction(
      _selectedUids.toList(),
      action,
      params: params,
    );
    
    if (!mounted) return;
    showCustomSnackBar(
      context,
      success ? 'Batch $action successful!' : 'Batch action failed.',
      type: success ? SnackBarType.success : SnackBarType.error,
    );
    
    if (success) {
      _fetchPlayers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedUids.isNotEmpty)
            _buildCAB()
          else
            _buildHeader(),
          const SizedBox(height: 16),

          // Search & Filters
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search by Name, Email, or UID',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _fetchPlayers(),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<bool?>(
                value: _filterBanned,
                hint: const Text('Banned Status'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Users')),
                  DropdownMenuItem(value: true, child: Text('Banned Only')),
                  DropdownMenuItem(value: false, child: Text('Active Only')),
                ],
                onChanged: (val) {
                  setState(() => _filterBanned = val);
                  _fetchPlayers();
                },
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _fetchPlayers,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.deepPurple,
                ),
                child: const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Player List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _players.isEmpty
                    ? const Center(child: Text('No players found.'))
                    : ListView.builder(
                        itemCount: _players.length,
                        itemBuilder: (context, index) {
                          final p = _players[index] as Map<String, dynamic>;
                          final uid = p['uid'] ?? '';
                          final isSelected = _selectedUids.contains(uid);
                          final isBanned = p['isBanned'] ?? false;
                          final isMuted = p['mutedUntil'] != null;
                          final isAdmin = p['isAdmin'] ?? false;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: LiquidGlassDialog(
                              width: double.infinity,
                              padding: EdgeInsets.zero,
                              child: ListTile(
                                selected: isSelected,
                                selectedTileColor: Colors.deepPurple.withValues(alpha: 0.1),
                                leading: Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleSelection(uid),
                                  activeColor: Colors.amberAccent,
                                ),
                                title: Text(
                                  p['displayName'] ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  p['email'] ?? 'No Email',
                                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isAdmin)
                                      const Icon(Icons.verified, color: Colors.amber, size: 20),
                                    if (isBanned)
                                      const Icon(Icons.block, color: Colors.red, size: 20),
                                    if (isMuted)
                                      const Icon(Icons.volume_off, color: Colors.orange, size: 20),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_right, color: Colors.white24),
                                  ],
                                ),
                                onLongPress: () => _toggleSelection(uid),
                                onTap: () => _showPlayerActions(p),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Player Management',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(
            Icons.refresh,
            size: 28,
            color: Colors.amberAccent,
          ),
          onPressed: _fetchPlayers,
          tooltip: 'Refresh Player List',
        ),
      ],
    );
  }

  Widget _buildCAB() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _selectedUids.clear()),
          ),
          Text(
            '${_selectedUids.length} Selected',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.block, color: Colors.redAccent),
            tooltip: 'Batch Ban',
            onPressed: () => _performBatchAction('ban'),
          ),
          IconButton(
            icon: const Icon(Icons.volume_off, color: Colors.orangeAccent),
            tooltip: 'Batch Mute (24h)',
            onPressed: () => _performBatchAction('mute', params: {'durationHours': 24}),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
            tooltip: 'Batch Unban/Unmute',
            onPressed: () => _performBatchAction('unban'),
          ),
        ],
      ),
    );
  }
}
