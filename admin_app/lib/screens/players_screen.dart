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
      showCustomSnackBar(
        context,
        'Error: ${e.toString().replaceAll('Exception: ', '')}',
        type: SnackBarType.error,
      );
    }
  }

  void _showPlayerActions(Map<String, dynamic> player) {
    showDialog(
      context: context,
      builder: (context) => PlayerActionsDialog(
        player: player,
        onActionComplete: _fetchPlayers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.deepPurple,
                ),
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
                : LiquidGlassDialog(
                    width: double.infinity,
                    padding: EdgeInsets.zero,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          showCheckboxColumn: false,
                          columns: const [
                            DataColumn(label: Text('Display Name')),
                            DataColumn(label: Text('Email')),
                            DataColumn(label: Text('UID')),
                            DataColumn(label: Text('Status')),
                          ],
                          rows: _players.map((p) {
                            final isBanned = p['isBanned'] ?? false;
                            final isMuted = p['mutedUntil'] != null;
                            final isAdmin = p['isAdmin'] ?? false;

                            return DataRow(
                              onSelectChanged: (_) => _showPlayerActions(p),
                              cells: [
                                DataCell(Text(p['displayName'] ?? 'Unknown')),
                                DataCell(Text(p['email'] ?? 'No Email')),
                                DataCell(Text(p['uid'] ?? '')),
                                DataCell(
                                  Row(
                                    children: [
                                      if (isAdmin)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(
                                            Icons.verified,
                                            color: Colors.amber,
                                            size: 16,
                                          ),
                                        ),
                                      if (isBanned)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(
                                            Icons.block,
                                            color: Colors.red,
                                            size: 16,
                                          ),
                                        ),
                                      if (isMuted)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(
                                            Icons.volume_off,
                                            color: Colors.orange,
                                            size: 16,
                                          ),
                                        ),
                                      if (!isAdmin && !isBanned && !isMuted)
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 16,
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
                  ),
          ),
        ],
      ),
    );
  }
}
