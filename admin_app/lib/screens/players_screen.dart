import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/liquid_glass_dialog.dart';

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

  void _toggleBan(String uid, bool currentStatus) async {
    final success = await _adminService.banUser(uid, !currentStatus);
    if (!mounted) return;
    
    if (success) {
      showCustomSnackBar(
        context, 
        currentStatus ? 'User unbanned!' : 'User banned!',
        type: SnackBarType.success
      );
      _fetchPlayers();
    }
  }

  Future<DateTime?> _pickCustomDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)), // 10 years max
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _showPlayerActions(Map<String, dynamic> player) {
    final uid = player['uid'] ?? '';
    final displayName = player['displayName'] ?? 'Unknown Player';
    final isBanned = player['isBanned'] ?? false;
    final isMuted = player['mutedUntil'] != null;

    showDialog(
      context: context,
      builder: (dialogContext) => Center(
        child: LiquidGlassDialog(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Player Actions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              
              // Player Info Header
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: Text(displayName[0].toUpperCase()),
                ),
                title: Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                subtitle: Text('UID: $uid\nEmail: ${player['email'] ?? 'N/A'}'),
              ),
              const SizedBox(height: 20),

              // Ban Section
              const Text('Account Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
              const SizedBox(height: 12),
              if (isBanned) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _toggleBan(uid, isBanned);
                    },
                    icon: const Icon(Icons.restore),
                    label: const Text('UNBAN PLAYER'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _toggleBan(uid, false);
                        },
                        icon: const Icon(Icons.block),
                        label: const Text('PERMANENT BAN'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final dt = await _pickCustomDateTime();
                          if (dt != null && mounted) {
                            Navigator.pop(dialogContext);
                            final success = await _adminService.banUser(uid, true, until: dt.toUtc().toIso8601String());
                            if (success) {
                              showCustomSnackBar(context, 'Temporary ban applied!', type: SnackBarType.success);
                              _fetchPlayers();
                            }
                          }
                        },
                        icon: const Icon(Icons.timer),
                        label: const Text('TEMP BAN'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),

              // Mute Section
              const Text('Chat Restrictions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
              const SizedBox(height: 12),
              if (isMuted) ...[
                Text('Currently Muted until: ${player['mutedUntil']}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      final success = await _adminService.muteUser(uid, 0);
                      if (success && mounted) {
                        showCustomSnackBar(context, 'User unmuted!', type: SnackBarType.success);
                        _fetchPlayers();
                      }
                    },
                    icon: const Icon(Icons.volume_up),
                    label: const Text('UNMUTE NOW'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.orangeAccent, side: const BorderSide(color: Colors.orangeAccent)),
                  ),
                ),
              ] else ...[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _muteButton(dialogContext, uid, '24h', 24),
                    _muteButton(dialogContext, uid, '3d', 24 * 3),
                    _muteButton(dialogContext, uid, '1w', 24 * 7),
                    _muteButton(dialogContext, uid, '1m', 24 * 30),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final dt = await _pickCustomDateTime();
                        if (dt != null && mounted) {
                          Navigator.pop(dialogContext);
                          final success = await _adminService.muteUser(uid, null, until: dt.toUtc().toIso8601String());
                          if (success) {
                            showCustomSnackBar(context, 'Custom mute applied!', type: SnackBarType.success);
                            _fetchPlayers();
                          }
                        }
                      },
                      icon: const Icon(Icons.edit_calendar),
                      label: const Text('Custom...'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _muteButton(BuildContext dialogContext, String uid, String label, int hours) {
    return ElevatedButton(
      onPressed: () async {
        Navigator.pop(dialogContext);
        final success = await _adminService.muteUser(uid, hours);
        if (success && mounted) {
          showCustomSnackBar(context, 'Muted for $label', type: SnackBarType.success);
          _fetchPlayers();
        }
      },
      style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
      child: Text(label),
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
                                      if (isAdmin) const Padding(
                                        padding: EdgeInsets.only(right: 4),
                                        child: Icon(Icons.verified, color: Colors.amber, size: 16),
                                      ),
                                      if (isBanned) const Padding(
                                        padding: EdgeInsets.only(right: 4),
                                        child: Icon(Icons.block, color: Colors.red, size: 16),
                                      ),
                                      if (isMuted) const Padding(
                                        padding: EdgeInsets.only(right: 4),
                                        child: Icon(Icons.volume_off, color: Colors.orange, size: 16),
                                      ),
                                      if (!isAdmin && !isBanned && !isMuted) const Icon(Icons.check_circle, color: Colors.green, size: 16),
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
