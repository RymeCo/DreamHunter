import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../services/admin_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/player_actions_dialog.dart';
import '../widgets/admin_ui_components.dart';

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
  bool _isMoreLoading = false;
  bool _hasMore = true;

  bool? _filterBanned;

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
      _hasMore = true;
    });
    try {
      final results = await _adminService.searchPlayers(
        query: _searchController.text.trim(),
        isBanned: _filterBanned,
      );
      if (!mounted) return;
      setState(() {
        _players = results;
        _isLoading = false;
        if (results.length < 20) _hasMore = false;
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

  Future<void> _loadMore() async {
    if (_isMoreLoading || !_hasMore || _players.isEmpty) return;
    setState(() => _isMoreLoading = true);
    
    try {
      final lastId = _players.last['uid'];
      final results = await _adminService.searchPlayers(
        query: _searchController.text.trim(),
        isBanned: _filterBanned,
        lastId: lastId,
      );
      
      if (!mounted) return;
      setState(() {
        _players.addAll(results);
        _isMoreLoading = false;
        if (results.length < 20) _hasMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isMoreLoading = false);
    }
  }

  void _showPlayerActions(Map<String, dynamic> player) {
    if (_selectedUids.isNotEmpty) {
      _toggleSelection(player['uid']);
      return;
    }
    showDialog(
      context: context,
      builder: (context) =>
          PlayerActionsDialog(player: player, onActionComplete: _fetchPlayers),
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

  Future<void> _performBatchAction(
    String action, {
    Map<String, dynamic>? params,
  }) async {
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
      if (mounted) {
        Provider.of<AdminProvider>(context, listen: false).refreshDashboard();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminHeader(
          title: 'Player Management',
          actions: [
            if (_selectedUids.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_selectedUids.length} selected',
                  style: const TextStyle(
                      color: Colors.amberAccent, fontWeight: FontWeight.bold),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.amberAccent),
              onPressed: _fetchPlayers,
              tooltip: 'Refresh List',
            ),
          ],
        ),

        // Search & Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AdminCard(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: AdminTextField(
                    controller: _searchController,
                    label: 'Search Players',
                    hint: 'Name, Email, or UID...',
                    prefixIcon: Icons.search_rounded,
                    onSubmitted: (_) => _fetchPlayers(),
                  ),
                ),
                _buildFilterDropdown(),
                AdminButton(
                  onPressed: _fetchPlayers,
                  label: 'SEARCH',
                  icon: Icons.filter_list_rounded,
                ),
                if (_selectedUids.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(width: 1, height: 30, color: Colors.white10),
                  const SizedBox(width: 8),
                  _batchActionButton(
                      Icons.block_flipped, Colors.redAccent, 'ban'),
                  _batchActionButton(
                      Icons.volume_off_rounded, Colors.orangeAccent, 'mute'),
                  _batchActionButton(
                      Icons.check_circle_outline, Colors.greenAccent, 'unban'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Player List
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.amberAccent))
                : _players.isEmpty
                    ? const Center(child: Text('No matching records found.'))
                    : _buildPlayerList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<bool?>(
          value: _filterBanned,
          hint: const Text('All Status', style: TextStyle(fontSize: 14)),
          dropdownColor: const Color(0xFF1E1E3A),
          items: const [
            DropdownMenuItem(value: null, child: Text('All Users')),
            DropdownMenuItem(value: true, child: Text('Banned')),
            DropdownMenuItem(value: false, child: Text('Active')),
          ],
          onChanged: (val) {
            setState(() => _filterBanned = val);
            _fetchPlayers();
          },
        ),
      ),
    );
  }

  Widget _batchActionButton(IconData icon, Color color, String action) {
    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: () => _performBatchAction(action),
      tooltip: 'Batch $action',
    );
  }

  Widget _buildPlayerList() {
    return ListView.builder(
      itemCount: _players.length + (_hasMore ? 1 : 0),
      padding: const EdgeInsets.only(bottom: 24),
      itemBuilder: (context, index) {
        if (index == _players.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: _isMoreLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
                : AdminButton(
                    onPressed: _loadMore,
                    label: 'LOAD MORE PLAYERS',
                    icon: Icons.expand_more_rounded,
                    color: Colors.white10,
                  ),
          );
        }

        final p = _players[index] as Map<String, dynamic>;
        final uid = p['uid'] ?? '';
        final isSelected = _selectedUids.contains(uid);
        final isBanned = p['isBanned'] ?? false;
        final isMuted = p['mutedUntil'] != null;
        final isAdmin = p['isAdmin'] ?? false;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AdminCard(
            padding: EdgeInsets.zero,
            borderColor: isSelected ? Colors.amberAccent : null,
            child: ListTile(
              onTap: () => _showPlayerActions(p),
              onLongPress: () => _toggleSelection(uid),
              leading: Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(uid),
                activeColor: Colors.amberAccent,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              title: Text(
                (p['displayName'] != null && p['displayName'].toString().isNotEmpty)
                    ? p['displayName']
                    : (p['email'] ?? uid),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                p['displayName'] != null ? (p['email'] ?? uid) : uid,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAdmin)
                    _statusIcon(Icons.verified_user_rounded, Colors.amber),
                  if (p['isModerator'] == true)
                    _statusIcon(Icons.shield_rounded, Colors.blueAccent),
                  if (isBanned) _statusIcon(Icons.block_rounded, Colors.red),
                  if (isMuted)
                    _statusIcon(Icons.volume_off_rounded, Colors.orange),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statusIcon(IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Icon(icon, color: color, size: 18),
    );
  }
}
