import 'package:flutter/material.dart';
import '../services/admin_service.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchPlayers();
  }

  Future<void> _fetchPlayers() async {
    setState(() => _isLoading = true);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  void _toggleBan(String uid, bool currentStatus) async {
    final success = await _adminService.banUser(uid, !currentStatus);
    if (success) _fetchPlayers();
  }

  void _showMuteDialog(String uid) {
    int duration = 1;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Mute User'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select duration in hours (0 to unmute):'),
                Slider(
                  value: duration.toDouble(),
                  min: 0,
                  max: 72,
                  divisions: 72,
                  label: '$duration hours',
                  onChanged: (val) {
                    setDialogState(() => duration = val.toInt());
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _adminService.muteUser(uid, duration);
                  _fetchPlayers();
                },
                child: const Text('Apply'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Player Management', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.refresh, size: 28, color: Colors.amberAccent),
              onPressed: _fetchPlayers,
              tooltip: 'Refresh Player List',
            ),
          ],
        ),
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
              style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.deepPurple),
              child: const Text('Search'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Data Table
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _players.isEmpty 
              ? const Center(child: Text('No players found.'))
              : SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Display Name')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('UID')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _players.map((p) {
                      final isBanned = p['isBanned'] ?? false;
                      final isMuted = p['mutedUntil'] != null;
                      final isAdmin = p['isAdmin'] ?? false;
                      
                      return DataRow(
                        cells: [
                          DataCell(Text(p['displayName'] ?? 'Unknown')),
                          DataCell(Text(p['email'] ?? 'No Email')),
                          DataCell(Text(p['uid'] ?? '')),
                          DataCell(
                            Row(
                              children: [
                                if (isAdmin) const Icon(Icons.verified, color: Colors.amber, size: 16),
                                if (isBanned) const Icon(Icons.block, color: Colors.red, size: 16),
                                if (isMuted) const Icon(Icons.volume_off, color: Colors.orange, size: 16),
                                if (!isAdmin && !isBanned && !isMuted) const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              ],
                            ),
                          ),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(isBanned ? Icons.restore : Icons.block, color: isBanned ? Colors.green : Colors.red),
                                  tooltip: isBanned ? 'Unban' : 'Ban',
                                  onPressed: () => _toggleBan(p['uid'], isBanned),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.volume_off, color: Colors.orange),
                                  tooltip: 'Mute',
                                  onPressed: () => _showMuteDialog(p['uid']),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }
}
