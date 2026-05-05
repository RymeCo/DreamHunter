import 'dart:convert';
import 'package:flutter/material.dart';
import '../../api_gateway.dart';
import '../../utils/formatters.dart';
import 'player_edit_dialog.dart';

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

  Map<String, dynamic> _leaderboardData = {};
  bool _isLoadingLeaderboard = false;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _forceRecalculate() async {
    setState(() => _isLoadingLeaderboard = true);
    try {
      final response = await _api.post('/leaderboard/refresh');
      if (response.statusCode == 200) {
        await _fetchLeaderboard();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLeaderboard = false);
    }
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoadingLeaderboard = true);
    try {
      final response = await _api.get('/admin/leaderboard');
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _leaderboardData = json.decode(response.body);
          _isLoadingLeaderboard = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLeaderboard = false);
      }
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.length < 2) return;

    setState(() => _isSearching = true);
    try {
      final response = await _api.get('/admin/players/search?q=$query');
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _searchResults = json.decode(response.body);
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    }
  }

  Future<void> _showPlayerDetails(String uid) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await _api.get('/admin/players/$uid');

      if (!mounted) return;
      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final player = json.decode(response.body);
        _showEditDialog(player);
      }
    } catch (e) {
      if (mounted) {
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
        return PlayerEditDialog(
          player: player,
          onUpdate: (updatedData) async {
            if (!dialogContext.mounted) return;

            final confirm = await showDialog<bool>(
              context: dialogContext,
              builder: (context) => AlertDialog(
                title: const Text('Confirm Changes'),
                content: const Text(
                  'Are you sure you want to apply these changes? This action is irreversible.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Apply',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              try {
                final response = await _api.patch(
                  '/admin/players/${player['uid']}',
                  body: updatedData,
                );

                if (!dialogContext.mounted) return;

                if (response.statusCode == 200) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Player updated successfully!'),
                    ),
                  );
                  Navigator.of(dialogContext).pop();
                  _search();
                  _fetchLeaderboard();
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
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
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(text: 'Player Management', icon: Icon(Icons.person_search)),
              Tab(text: 'Leaderboard Viewer', icon: Icon(Icons.leaderboard)),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.outline,
            indicatorColor: Theme.of(context).colorScheme.primary,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSearchTab(),
                _buildLeaderboardTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search Players',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Search for players by Name or UID.'),
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
                child: _isSearching
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Search'),
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
                      return _buildPlayerCard(p);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    if (_isLoadingLeaderboard && _leaderboardData.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final topLevels = _leaderboardData['topLevels'] as List<dynamic>? ?? [];
    final topCoins = _leaderboardData['topCoins'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: _fetchLeaderboard,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Global Leaderboards',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Updated: ${_leaderboardData['lastUpdated'] != null ? AppFormatters.formatFullDateTime(DateTime.parse(_leaderboardData['lastUpdated'])) : "Never"}',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _isLoadingLeaderboard ? null : _forceRecalculate,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Force Recalculate'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildLeaderboardSection('Top Levels', topLevels, Icons.trending_up, Colors.blue),
          const SizedBox(height: 32),
          _buildLeaderboardSection('Top Coins', topCoins, Icons.monetization_on, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildLeaderboardSection(String title, List<dynamic> entries, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const Text('No entries found.')
        else
          ...entries.asMap().entries.map((e) {
            final idx = e.key;
            final p = e.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: idx == 0 ? Colors.amber : (idx == 1 ? Colors.grey.shade300 : (idx == 2 ? Colors.orange.shade200 : Colors.blue.shade50)),
                  child: Text('${idx + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: idx < 3 ? Colors.black87 : Colors.blue)),
                ),
                title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('LVL ${p['level']}'),
                trailing: Text(
                  '${p['value']}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
                ),
                onTap: () => _showPlayerDetails(p['uid']),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildPlayerCard(Map<String, dynamic> p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: p['role'] == 'admin' ? Colors.deepPurple : Colors.blue.shade100,
          child: Icon(
            p['role'] == 'admin' ? Icons.admin_panel_settings : Icons.person,
            color: p['role'] == 'admin' ? Colors.white : Colors.blue,
          ),
        ),
        title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('LVL ${p['level']} • ${p['email'] ?? "No Email"}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showPlayerDetails(p['uid']),
      ),
    );
  }
}
